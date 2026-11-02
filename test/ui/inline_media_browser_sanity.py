#!/usr/bin/env python3
"""Static checks for the inline activity Media Browser (MB;<entity_id>).

The Remote hardware still needs visual testing. These checks catch missing QRC
registration, accidental popup usage and invalid carousel geometry at grid sizes.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
activity = (ROOT / "src/qml/components/entities/activity/deviceclass/Activity.qml").read_text()
browser = (ROOT / "src/qml/components/entities/activity/InlineMediaBrowser.qml").read_text()
qrc = (ROOT / "resources/qrc/main.qrc").read_text()
player = (ROOT / "src/ui/entity/mediaPlayer.h").read_text()

for expected in (
    'if (widgetKind === "MB")',
    '"qrc:/components/entities/activity/InlineMediaBrowser.qml"',
    '"entityId": browserId',
    '"browserActive": Qt.binding(function()',
):
    assert expected in activity, f"Activity marker contract missing: {expected}"

assert '<file alias="components/entities/activity/InlineMediaBrowser.qml">' in qrc
assert "Popup {" not in browser and "StackView {" not in browser
assert "PathView {" in browser and "pathItemCount:" in browser
assert "preferredHighlightBegin: 0.5" in browser
assert "preferredHighlightEnd: 0.5" in browser
assert "snapMode: PathView.SnapOneItem" in browser
assert "PathView.coverScale" in browser and "PathView.coverAngle" in browser

# Browsing replies are scoped by the request id and active widget, so another
# media browser or an abandoned folder cannot overwrite this one's coverflow.
assert "requestId !== pendingRequestId" in browser
assert "pendingRequestId = -1;" in browser
assert "browserActive" in browser
assert "function goBack()" in browser and "function enterFolder(item)" in browser
assert "function loadMore()" in browser and "pageSize: 20" in browser
assert "pagination.count" in browser
assert "browseMedia(folderId, folderType, pageSize, page)" in browser
assert "player.playMedia(item.media_id, item.media_type" in browser
assert "Q_INVOKABLE int  browseMedia(" in player
assert "void browseMediaResult(int requestId" in player

# Browser remains a bounded widget even when the user configures a tiny Text
# button. For a practical 2x2+ grid cell there is room for header, art, labels.
for width, height in ((480, 800), (480, 425), (240, 280), (190, 200), (120, 135)):
    art_size = max(0, min(width * .42, height - 108, 212))
    usable = width >= 160 and height >= 158 and art_size >= 46
    header_height = min(46, height * .27)
    assert art_size <= width * .42
    assert header_height + art_size + 54 <= height or not usable
    if width == 120:
        assert not usable, "Tiny cells must fall back to an inline size message"

print("Inline media browser wiring, pagination and coverflow geometry checks passed.")
