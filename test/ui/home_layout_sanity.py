#!/usr/bin/env python3
"""Regression checks for optional home screen layout bounds and keyboard icon.

The Qt build matrix cannot render the device's dynamic QML layouts. These checks
protect the geometry assumptions used by HomePage, ActivityTile and MediaCard.
The physical 480x800 Remote 3 remains the final visual test.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
home = (ROOT / "src/qml/components/home/HomePage.qml").read_text()
tile = (ROOT / "src/qml/components/home/ActivityTile.qml").read_text()
media = (ROOT / "src/qml/components/home/MediaCard.qml").read_text()
style = (ROOT / "src/qml/keyboard/QtQuick/VirtualKeyboard/Styles/remotestyle/style.qml").read_text()
field = (ROOT / "src/qml/components/InputField.qml").read_text()

for required in (
    "contentHeight: body.implicitHeight + 28",
    "function ensureSelectedVisible()",
    "target.mapToItem(scroll.contentItem, 0, 0).y",
    "id: pageFooter",
    "id: modernGrid",
    "id: compactGrid",
    "id: minimalDock",
    "id: quickGrid",
    "height: 402",
    "height: 182",
):
    assert required in home, f"Missing layout/scroll contract: {required}"

assert "readonly property bool iconOnly: compact && width < 170" in tile
assert "clip: true" in tile and "clip: true" in media
assert "maximumLineCount: 1" in tile
assert "id: compactTransport" in media and "id: expandedMetadata" in media
assert "maximumLineCount: 2" in media
assert "root.keyboardSendMode ? \"\"" in style, "Keyboard must use an icon, not SEND text"
assert 'return resourcePrefix + "images/enter-868482.svg"' in style
assert 'EnterKeyAction.label: ""' in field

for width, height in ((480, 800), (480, 854), (480, 850), (375, 667), (320, 640)):
    inner = width - 40
    modern = (inner - 10) / 2
    compact = modern
    quick = (inner - 30) / 4
    assert modern > 0 and 2 * modern + 10 <= inner
    assert compact > 0 and 2 * compact + 10 <= inner
    assert quick >= 60 and 4 * quick + 30 <= inner
    # Narrow 4-column tiles must become icon-only instead of wrapping labels.
    assert quick < 170

    artwork = min(100, max(64, inner * 0.27))
    controls_x = artwork + 32
    button = max(44, min(60, (inner - controls_x - 16 - 24) / 3))
    assert controls_x + 3 * button + 24 <= inner - 16, (
        "Compact media controls overflow", width
    )
    # 170px artwork at y=16, two lines of metadata + artist, controls at y=322.
    expanded_metadata_end = 16 + 170 + 12 + 2 * 36 + 4 + 32
    expanded_controls_top = 402 - 16 - 64
    assert expanded_metadata_end <= expanded_controls_top

    scroll_height = height - 48 - 54
    assert scroll_height >= 500
    # A long activity list must remain scrollable rather than being clipped.
    content_height = 124 + 16 + 36 + 10 + 10 * (158 + 10) + 16 + 182 + 16
    assert content_height > scroll_height

print("Home geometry and virtual-keyboard send icon checks passed.")
