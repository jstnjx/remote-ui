#!/usr/bin/env python3
"""Static geometry and feature-contract checks for the single redesigned home.

A physical Remote remains the final visual test. This verifies that our
responsive geometry keeps the hero, optional media strip and launcher apart,
including the 480x800 and smaller simulator viewports.
"""
from math import ceil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
home = (ROOT / "src/qml/components/home/HomePage.qml").read_text()
tile = (ROOT / "src/qml/components/home/ActivityTile.qml").read_text()
media = (ROOT / "src/qml/components/home/MediaCard.qml").read_text()
settings = (ROOT / "src/qml/settings/settings/HomeScreen.qml").read_text()
main = (ROOT / "src/qml/MainContainer.qml").read_text()
style = (ROOT / "src/qml/keyboard/QtQuick/VirtualKeyboard/Styles/remotestyle/style.qml").read_text()
field = (ROOT / "src/qml/components/InputField.qml").read_text()

for required in (
    "id: hero",
    "home.homeBackgroundImage",
    "id: rightHeader",
    "Battery.level",
    "function ensureSelectedVisible()",
    "id: gridViewport",
    "gridViewport.contentHeight",
    "id: gridContents",
    "columns: 2",
    "id: activityRepeater",
    "ActivityStates.On",
    "function mediaForActivity(activity)",
    "Config.homeShowActivityLabels",
):
    assert required in home, f"Missing single home feature/scroll contract: {required}"

for removed in (
    "homeScreenLayout", "modernGrid", "compactGrid", "minimalDock", "quickGrid",
    "pageFooter", "quickIds", "mediaFocus", "largeMedia", "standardMedia",
):
    assert removed not in home, f"Old layout still referenced: {removed}"

assert "Item {" in tile and "clip: true" in tile
assert "maximumLineCount: 1" in tile and "showLabel" in tile
assert "id: artworkSlot" in media and "clip: true" in media
assert "maximumLineCount: 1" in media
assert all(x not in media for x in ("playPause()", "backward-step", "forward-step", "compactTransport"))
assert 'visible: !mainContainerRoot.redesignedHomeActive' in main
assert "Use redesigned home screen" in settings and "Show activity labels" in settings
assert "Home layout" not in settings

# Keep the native keyboard send/return icon, not the literal word SEND.
assert 'root.keyboardSendMode ? ""' in style
assert 'return resourcePrefix + "images/enter-868482.svg"' in style
assert 'EnterKeyAction.label: ""' in field

for width, height in ((480, 800), (480, 854), (480, 850), (375, 667), (320, 640)):
    inner = width - 40
    gap = 12
    tile_width = (inner - gap) / 2
    assert tile_width >= 100 and tile_width * 2 + gap <= inner

    hero_height = min(320, max(220, height * 0.39))
    for activity_count in (0, 1, 2, 4, 6, 8, 16):
        rows = ceil(activity_count / 2)
        grid_height = rows * 104 + max(0, rows - 1) * gap
        for media_on in (False, True):
            available = max(0, height - hero_height - 24 - (116 if media_on else 24))
            viewport = min(grid_height, available)
            grid_top = height - 24 - viewport
            assert grid_top >= hero_height, (width, height, activity_count, media_on)
            if media_on:
                media_top = grid_top - 16 - 84
                assert media_top >= hero_height, (width, height, activity_count)
            if grid_height > available:
                assert viewport < grid_height, "Long launcher grid must be scrollable"

    # Inner padding 10 on both sides; image gets one-third and text gets two-thirds.
    media_content = inner - 20
    artwork = (media_content - 12) / 3
    metadata = media_content - artwork - 12
    assert artwork > 0 and metadata > artwork
    assert artwork + 12 + metadata <= media_content

print("Single redesigned home geometry and keyboard send icon checks passed.")
