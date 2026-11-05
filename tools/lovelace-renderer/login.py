#!/usr/bin/env python3
"""One-time interactive login to Home Assistant using the same Chromium profile."""
import asyncio
import os
from pathlib import Path
from playwright.async_api import async_playwright

async def main():
    origin = os.environ["HA_ORIGIN"].rstrip("/")
    profile = str(Path(os.environ.get("LOVELACE_PROFILE", str(Path(__file__).resolve().parent / "browser-profile"))).expanduser().resolve())
    print(f"Using Chromium profile: {profile}")
    async with async_playwright() as pw:
        context = await pw.chromium.launch_persistent_context(
            profile, headless=False, viewport={"width": 480, "height": 850})
        page = context.pages[0] if context.pages else await context.new_page()
        await page.goto(origin, wait_until="domcontentloaded")
        print("Sign in to Home Assistant and verify the dashboard opens, then press Enter.")
        print("Run login.py while server.py is stopped; profiles cannot be shared.")
        await asyncio.to_thread(input)
        await context.close()

if __name__ == "__main__":
    asyncio.run(main())
