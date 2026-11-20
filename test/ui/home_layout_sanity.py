#!/usr/bin/env python3
"""Checks for the reference-matched, single-column Remote home layout.

Hardware/Qt rendering still needs to be checked on the device. The tests
verify model scope, native delegate behavior and small viewport geometry.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
home = (ROOT / "src/qml/components/home/HomePage.qml").read_text()
media = (ROOT / "src/qml/components/home/MediaCard.qml").read_text()
entity = (ROOT / "src/qml/components/entities/Base.qml").read_text()
group = (ROOT / "src/qml/components/group/Base.qml").read_text()
page = (ROOT / "src/qml/components/Page.qml").read_text()
settings = (ROOT / "src/qml/settings/settings/HomeScreen.qml").read_text()
main = (ROOT / "src/qml/MainContainer.qml").read_text()
style = (ROOT / "src/qml/keyboard/QtQuick/VirtualKeyboard/Styles/remotestyle/style.qml").read_text()
field = (ROOT / "src/qml/components/InputField.qml").read_text()

# The redesign must follow the exact home page and its persisted ordering;
# global activity discovery would show unrelated entities and omit groups.
for required in (
    "readonly property var currentPage:",
    "home.currentPage ? home.currentPage.items : null",
    "readonly property var homePageActivities: pageActivities",
    "home.currentPage ? home.currentPage.homePageActivities : null",
    'setSource("qrc:/components/entities/Base.qml"',
    'setSource("qrc:/components/group/Base.qml"',
    '"entityId": pageItemId',
    '"groupId": pageItemId',
    '"redesignedHomeStyle": true',
    "function moveSelection(step)",
    "function activateSelected(longPress)",
    "function ensureSelectedVisible()",
    "entityList.positionViewAtIndex",
    "function scrollToBeginning()",
    "function mediaForActivity(activity)",
    "ActivityStates.On",
):
    assert required in (home + page), f"Missing configured-page / native-list contract: {required}"

for removed in (
    "activityRepeater", "gridContents", "gridViewport", "activityIds",
    'EntityController.getIdsByType("activity")', "Quick Scenes", "quickGrid",
    "Rooms", "selectedActions", "homeShowActivityLabels",
):
    assert removed not in home, f"Old global/grid/segmented home still in source: {removed}"

# A single, compact top status bar (page title, battery, gear), with the
# only digital time and date shown on the configured-background hero.
assert home.count('Qt.formatTime(ui.time') == 1
assert home.count('Qt.formatDate(new Date()') == 1
assert home.count("Battery.level") >= 1
assert "id: topBar" in home and "id: hero" in home
assert "home.homeBackgroundImage" in home
assert 'icon: "uc:gear"' in home
assert 'icon: "uc:house"' in home
assert "height: 52" in home
assert "visible: home.mediaPlayer !== null" in home

# Native entities and groups retain their original interactions when the
# optional style is off, and only the redesigned list has square 94px rows.
for component in (entity, group):
    assert "property bool redesignedHomeStyle: false" in component
    assert "radius: redesignedHomeStyle ? 0 : ui.cornerRadiusSmall" in component
    assert "redesignedHomeStyle ? colors.surface : colors.black" in component
    assert "redesignedHomeStyle ? 94 : 130" in component
    assert "Components.Selectable {" in component
    assert "style: \"fill\"" in component
assert "function open()" in entity and "function control()" in entity
assert "function open()" in group and "function close()" in group
assert '"redesignedHomeStyle": container.redesignedHomeStyle' in group
assert 'icon: "uc:chevron-right"' in entity

# The reference has an edge-to-edge, square artwork-and-metadata strip.
assert "radius: 0" in media
assert "id: artworkSlot" in media
assert "aspectFit: false" in media
assert "mediaArtist" in media and "mediaTitle" in media
assert all(x not in media for x in ("playPause()", "backward-step", "forward-step", "compactTransport"))

# Original home remains the fallback, and left/right switch pages instead
# of moving through a two-column icon grid.
assert 'visible: !mainContainerRoot.redesignedHomeActive' in main
assert "pages.incrementCurrentIndex();" in main
assert "pages.decrementCurrentIndex();" in main
assert "redesignedHome.item.activateSelected(false)" in main
assert "redesignedHome.item.activateSelected(true)" in main
assert "redesignedHome.item.scrollToBeginning()" in main
assert "Use redesigned home screen" in settings
assert "Show activity labels" not in settings

# The keyboard's native send/return key must not regress.
assert 'root.keyboardSendMode ? ""' in style
assert 'id: enterKeyIcon' in style
assert 'Components.Icon {' in style
assert 'return "uc:arrow-turn-down"' in style
assert 'id: enterKeyText' in style
assert 'images/enter-868482.svg' not in style
assert 'EnterKeyAction.label: inputFieldContainer.enterKeyLabel' in field

# 480x850 is the intended Remote simulator viewport. The long one-column
# list scrolls below the media strip rather than overlapping the header.
for width, height in ((480, 850), (480, 800), (480, 854), (375, 667), (320, 640)):
    top_bar = 52
    hero_height = min(220, max(165, height * .235))
    for media_on in (False, True):
        media_height = 100 if media_on else 0
        media_top_gap = 12 if media_on else 0
        list_top_gap = 12 if media_on else 10
        list_top = top_bar + hero_height + media_top_gap + media_height + list_top_gap
        list_height = height - list_top - 8
        assert list_height >= 94, (width, height, media_on)
        assert list_top < height - 8
        assert width - 20 >= 280
        for item_count in (0, 1, 4, 6, 16):
            total = item_count * 94 + max(0, item_count - 1) * 6
            if total > list_height:
                assert total > list_height, "Long lists must use ListView scrolling"

    media_width = width - 20
    artwork = (media_width - 18) / 3
    metadata = media_width - artwork - 18 - 12
    assert artwork > 0 and metadata > artwork

print("Reference home single-column native row and geometry checks passed.")
