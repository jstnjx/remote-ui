#!/usr/bin/env python3
"""Lovelace Chromium rendering service for Remote-UI.

Run on a trusted machine on the same LAN as the remote, not on the remote.
A persistent Chromium profile holds the Home Assistant login session.
Only dashboard URLs under HA_ORIGIN are accepted.
"""
import asyncio
import json
import logging
import os
from pathlib import Path
from urllib.parse import urlsplit
from aiohttp import web
from playwright.async_api import async_playwright

ORIGIN = os.environ.get("HA_ORIGIN", "").rstrip("/")
PROFILE = Path(os.environ.get("LOVELACE_PROFILE", str(Path(__file__).resolve().parent / "browser-profile"))).expanduser().resolve()
HOST = os.environ.get("LOVELACE_HOST", "127.0.0.1")
PORT = int(os.environ.get("LOVELACE_PORT", "8765"))
FPS_LIMIT = float(os.environ.get("LOVELACE_FPS_LIMIT", "3"))
ALLOWED_ORIGIN = urlsplit(ORIGIN)
pages = {}
locks = {}
last_frame = {}
browser = None
playwright = None
log = logging.getLogger("lovelace-renderer")


def allowed(url):
    parts = urlsplit(url)
    return (
        ALLOWED_ORIGIN.scheme in ("http", "https")
        and parts.scheme == ALLOWED_ORIGIN.scheme
        and parts.netloc == ALLOWED_ORIGIN.netloc
        and not parts.username and not parts.password
        and not parts.fragment
    )


async def page_for(url, width, height):
    if not allowed(url):
        raise web.HTTPForbidden(text="URL must use the configured Home Assistant origin")
    # A small fixed cache prevents arbitrary browser tab proliferation.
    if url not in pages and len(pages) >= 8:
        old = next(iter(pages))
        await pages.pop(old).close()
        locks.pop(old, None)
        last_frame.pop(old, None)
    if url not in pages:
        page = await browser.new_page()
        pages[url] = page
        locks[url] = asyncio.Lock()
        await page.goto(url, wait_until="domcontentloaded", timeout=30000)
        log.info("Dashboard opened: %s -> %s", urlsplit(url).path, urlsplit(page.url).path)
    page = pages[url]
    if page.viewport_size != {"width": width, "height": height}:
        await page.set_viewport_size({"width": width, "height": height})
    return page


async def screenshot(request):
    url = request.query.get("url", "")
    try:
        width = max(160, min(960, int(request.query.get("width", "480"))))
        height = max(160, min(1600, int(request.query.get("height", "796"))))
    except ValueError:
        raise web.HTTPBadRequest(text="Invalid viewport")
    page = await page_for(url, width, height)
    async with locks[url]:
        # Do not silently stream the Home Assistant login page.
        destination = urlsplit(page.url)
        if destination.path.startswith("/auth/") or destination.path.startswith("/login"):
            log.warning("Home Assistant login required (profile %s)", PROFILE)
            raise web.HTTPUnauthorized(
                text="Home Assistant needs authentication. Stop the renderer and "
                     "run login.py using the same HA_ORIGIN and LOVELACE_PROFILE.")
        # Constrain CPU even if a client polls faster than the configured limit.
        now = asyncio.get_running_loop().time()
        previous = last_frame.get(url)
        if previous and now - previous[0] < 1.0 / max(0.2, FPS_LIMIT):
            data = previous[1]
        else:
            data = await page.screenshot(type="jpeg", quality=65, animations="disabled")
            last_frame[url] = (now, data)
    return web.Response(body=data, content_type="image/jpeg",
                        headers={"Cache-Control": "no-store"})


async def touch_swipe(page, x, y, to_x, to_y):
    """Send real mobile touch gestures, not mouse drag events.

    Lovelace mobile cards and browser scrolling listen to touch events.
    Chromium's CDP dispatch produces trusted touch input.
    """
    session = await page.context.new_cdp_session(page)
    try:
        await session.send("Input.dispatchTouchEvent", {
            "type": "touchStart",
            "touchPoints": [{"x": x, "y": y, "id": 1}],
        })
        steps = max(6, min(20, int(max(abs(to_x - x), abs(to_y - y)) / 18)))
        for step in range(1, steps + 1):
            part = step / steps
            await session.send("Input.dispatchTouchEvent", {
                "type": "touchMove",
                "touchPoints": [{
                    "x": x + (to_x - x) * part,
                    "y": y + (to_y - y) * part,
                    "id": 1,
                }],
            })
            await asyncio.sleep(0.016)
    finally:
        await session.send("Input.dispatchTouchEvent", {
            "type": "touchEnd", "touchPoints": [],
        })
        await session.detach()


async def input_event(request):
    url = request.query.get("url", "")
    if not allowed(url):
        raise web.HTTPForbidden(text="Dashboard URL is not under HA_ORIGIN")
    if url not in pages:
        raise web.HTTPConflict(text="Open the dashboard frame first")

    try:
        # QML sends text/plain to avoid browser preflight; accept application/json
        # for diagnostics and third-party clients as well.
        data = json.loads(await request.text())
        if not isinstance(data, dict):
            raise ValueError("JSON object expected")
        kind = data.get("type")
        x, y = float(data.get("x", 0)), float(data.get("y", 0))
        page = pages[url]
        viewport = page.viewport_size or {"width": 480, "height": 796}
        x = max(0, min(viewport["width"] - 1, x))
        y = max(0, min(viewport["height"] - 1, y))
        if kind in ("swipe", "scroll"):
            to_x = float(data.get("toX", x))
            to_y = float(data.get("toY", y))
    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        raise web.HTTPBadRequest(text=f"Invalid input data: {exc}") from exc

    async with locks[url]:
        if kind == "click":
            await page.touchscreen.tap(x, y)
        elif kind == "swipe":
            to_x = max(0, min(viewport["width"] - 1, to_x))
            to_y = max(0, min(viewport["height"] - 1, to_y))
            await touch_swipe(page, x, y, to_x, to_y)
        elif kind == "scroll":
            await page.mouse.wheel(0, float(data.get("deltaY", 0)))
        else:
            raise web.HTTPBadRequest(text="Unknown input event")
        last_frame.pop(url, None)
    log.info("Input %s on %s (%.0f, %.0f)", kind, urlsplit(url).path, x, y)
    return web.json_response({"ok": True})


@web.middleware
async def cors_middleware(request, handler):
    # The remote's QML XMLHttpRequest does not share Chromium's origin.
    # Do not publish this unauthenticated endpoint beyond a trusted LAN.
    if request.method == "OPTIONS" and request.path == "/input":
        response = web.Response(status=204)
    else:
        response = await handler(request)
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return response


async def preflight(request):
    return web.Response(status=204)


async def health(request):
    return web.json_response({
        "ok": True,
        "dashboards": len(pages),
        "profile_directory": str(PROFILE),
        "sessions": [{
            "dashboard_path": urlsplit(url).path,
            "browser_path": urlsplit(page.url).path,
            "login_required": (urlsplit(page.url).path.startswith("/auth/") or
                               urlsplit(page.url).path.startswith("/login"))
        } for url, page in pages.items()]
    })


async def on_startup(app):
    global browser, playwright
    if not ORIGIN or ALLOWED_ORIGIN.scheme not in ("http", "https"):
        raise RuntimeError("Set HA_ORIGIN=http(s)://your-home-assistant:8123")
    log.info("Chromium profile directory: %s", PROFILE)
    playwright = await async_playwright().start()
    browser = await playwright.chromium.launch_persistent_context(
        str(PROFILE), headless=True,
        viewport={"width": 480, "height": 796}, is_mobile=True, has_touch=True,
        device_scale_factor=1,
        args=["--no-first-run", "--disable-background-networking"])
    # Session data remains in the profile directory on the rendering host.


async def on_cleanup(app):
    if browser:
        await browser.close()
    if playwright:
        await playwright.stop()


async def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    app = web.Application(client_max_size=4096, middlewares=[cors_middleware])
    app.router.add_get("/frame", screenshot)
    app.router.add_post("/input", input_event)
    app.router.add_options("/input", preflight)
    app.router.add_get("/health", health)
    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)
    print(f"Listening on {HOST}:{PORT}; accessible Home Assistant origin: {ORIGIN}")
    await web._run_app(app, host=HOST, port=PORT)


if __name__ == "__main__":
    asyncio.run(main())
