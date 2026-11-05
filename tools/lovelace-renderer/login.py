#!/usr/bin/env python3
"""One-time interactive login to Home Assistant using the same Chromium profile."""
import asyncio
import os
from pathlib import Path
from playwright.async_api import async_playwright

async def main():
    origin = os.environ["HA_ORIGIN"].rstrip("/")
    profile = str(Path(os.environ.get("LOVELACE_PROFILE", "./browser-profile")).resolve())
    async with async_playwright() as pw:
        context = await pw.chromium.launch_persistent_context(
            profile, headless=False, viewport={"width": 480, "height": 850})
        page = context.pages[0] if context.pages else await context.new_page()
        await page.goto(origin)
        print("Sign in to Home Assistant, then press Enter here to save the session.")
        await asyncio.to_thread(input)
        await context.close()

if __name__ == "__main__":
    asyncio.run(main())
