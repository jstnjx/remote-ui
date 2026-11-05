#!/usr/bin/env python3
"""Lovelace Chromium rendering service for Remote-UI.

Run on a trusted machine on the same LAN as the remote, not on the remote.
A persistent Chromium profile holds the Home Assistant login session.
Only dashboard URLs under HA_ORIGIN are accepted.
"""
import asyncio
import os
from pathlib import Path
from urllib.parse import urlsplit
from aiohttp import web
from playwright.async_api import async_playwright

ORIGIN = os.environ.get("HA_ORIGIN", "").rstrip("/")
PROFILE = Path(os.environ.get("LOVELACE_PROFILE", "./browser-profile")).resolve()
HOST = os.environ.get("LOVELACE_HOST", "127.0.0.1")
PORT = int(os.environ.get("LOVELACE_PORT", "8765"))
FPS_LIMIT = float(os.environ.get("LOVELACE_FPS_LIMIT", "3"))
ALLOWED_ORIGIN = urlsplit(ORIGIN)
pages = {}
locks = {}
last_frame = {}
browser = None
playwright = None


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


async def input_event(request):
    url = request.query.get("url", "")
    if not allowed(url):
        raise web.HTTPForbidden()
    if url not in pages:
        raise web.HTTPConflict(text="Open dashboard first")
    data = await request.json()
    page = pages[url]
    x, y = float(data.get("x", 0)), float(data.get("y", 0))
    async with locks[url]:
        kind = data.get("type")
        if kind == "click":
            await page.mouse.click(x, y)
        elif kind == "swipe":
            await page.mouse.move(x, y)
            await page.mouse.down()
            dest_x, dest_y = float(data.get("toX", x)), float(data.get("toY", y))
            await page.mouse.move(dest_x, dest_y, steps=12)
            await page.mouse.up()
        elif kind == "scroll":
            await page.mouse.move(x, y)
            await page.mouse.wheel(0, float(data.get("deltaY", 0)))
        else:
            raise web.HTTPBadRequest(text="Unknown input event")
        last_frame.pop(url, None)
    return web.json_response({"ok": True})


async def on_startup(app):
    global browser, playwright
    if not ORIGIN or ALLOWED_ORIGIN.scheme not in ("http", "https"):
        raise RuntimeError("Set HA_ORIGIN=http(s)://your-home-assistant:8123")
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
    app = web.Application(client_max_size=4096)
    app.router.add_get("/frame", screenshot)
    app.router.add_post("/input", input_event)
    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)
    print(f"Listening on {HOST}:{PORT}; accessible Home Assistant origin: {ORIGIN}")
    await web._run_app(app, host=HOST, port=PORT)


if __name__ == "__main__":
    asyncio.run(main())
