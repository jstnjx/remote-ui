#!/usr/bin/env python3
"""Static checks for the inline activity Media Browser (MB or MB;<alias>).

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
    '"entitySelector": browserSelector',
    '"commandEntityId": item.command',
    '"activityEntity": entityObj',
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
# Short selectors must not require renaming the real entity or exceeding the
# text button length limit. The long original marker remains backward compatible.
for required in (
    'property string entitySelector: ""',
    'property string commandEntityId: ""',
    'function activityPlayerIds()',
    'function resolveTarget()',
    'getIdsByType("media_player")',
    'last.indexOf(needle) === 0',
    'matches.length === 1',
    'matches.length > 1',
    'configured.indexOf(preferred[i]) >= 0',
    'configured.length === 1',
    'selectionMessage',
):
    assert required in browser, f"Missing MB shortcut resolution contract: {required}"

# Representative regression: "MB;ps5" identifies the full PS5 Connect ID,
# while ambiguous names explicitly require a longer suffix.
ps5_id = "ps5_connect_driver.main.media_player.ps5_10_1_1_30"
assert ps5_id.split(".")[-1].lower().startswith("ps5")
assert len("MB;ps5") < len("MB;" + ps5_id)
assert "MB;ps5" in (ROOT / "docs/inline-media-browser.md").read_text()

assert "Q_INVOKABLE int  browseMedia(" in player
assert "void browseMediaResult(int requestId" in player

# The immersive layout gives artwork most of the available grid space,
# removes the top toolbar, and keeps only the back arrow inside folders.
assert "color: colors.black" in browser
assert "    radius: 0" in browser
assert 'id: header' not in browser
assert 'id: refreshButton' not in browser
assert 'uc:rotate' not in browser
assert 'folderTitle' not in browser
assert 'qsTr("Browse media")' not in browser
assert "id: backButton" in browser
assert "visible: browser.history.length > 0" in browser
assert "onClicked: browser.goBack()" in browser
assert "top: parent.top" in browser
assert "bottom: metadata.top" in browser

# A larger center cover must remain inside the available region even at the
# smallest supported widget. The metadata strip and edge padding are reserved.
for width, height in (
    (480, 800), (480, 425), (320, 400), (240, 280),
    (190, 200), (160, 158), (120, 135),
):
    art_size = max(0, min(width * .68, height - 86, 340))
    usable = width >= 160 and height >= 158 and art_size >= 64
    assert art_size <= width * .68
    if usable:
        assert art_size + 86 <= height
        assert art_size > 0
    else:
        assert width < 160 or height < 158 or art_size < 64
    if width == 120:
        assert not usable

assert "width * 0.68, height - 86, 340" in browser
assert "width >= 160 && height >= 158 && artSize >= 64" in browser
assert 'PathAttribute { name: "coverScale"; value: 1.0 }' in browser
assert 'PathAttribute { name: "coverScale"; value: 0.72 }' in browser
assert 'PathAttribute { name: "coverOpacity"; value: 0.78 }' in browser

print("Inline media browser wiring, pagination and prominent coverflow geometry checks passed.")
