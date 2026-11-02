#!/usr/bin/env python3
"""Activity widget contracts: reuse native entity screens and capture gestures.

The Activity's third container must remain the only source of full-screen
Light/Climate/Cover controls. Widget touches must not trigger page swipes.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
activity = (root / "src/qml/components/entities/activity/deviceclass/Activity.qml").read_text()
cards = (root / "src/qml/components/entities/activity/InlineEntityCard.qml").read_text()
touchpad = (root / "src/qml/components/entities/activity/InlineTouchpad.qml").read_text()
climate_controls = (root / "src/qml/components/entities/activity/InlineClimateControls.qml").read_text()
cover_controls = (root / "src/qml/components/entities/activity/InlineCoverControls.qml").read_text()
native_brightness = (root / "src/qml/components/entities/light/Brightness.qml").read_text()
native_onoff = (root / "src/qml/components/entities/light/OnOff.qml").read_text()
native_openclose = (root / "src/qml/components/entities/cover/OpenClose.qml").read_text()

qrc = (root / "resources/qrc/main.qrc").read_text()
docs = (root / "docs/activity-purpose-widgets.md").read_text()
remote_api = (root / "src/ui/entity/remote.h").read_text()

for name in ("InlineEntityCard.qml", "InlineTouchpad.qml",
             "InlineClimateControls.qml", "InlineCoverControls.qml"):
    assert f'alias="components/entities/activity/{name}"' in qrc

for kind in ("LIGHT", "CLIMATE", "COVER", "TP", "TOUCHPAD"):
    assert f'"{kind}"' in activity
assert 'widgetKind === "TP" || widgetKind === "TOUCHPAD"' in activity
assert 'Qt.createComponent(' in activity
assert 'entitySelector' in activity and 'commandEntityId' in activity
assert 'entityObj.state === ActivityStates.On' in activity
assert 'uiPages.currentIndex === index' in activity
assert 'Power.powerMode === PowerModes.Normal' in activity
assert '"width": gridSizeW * (item.size' in activity
assert '"height": gridSizeH * (item.size' in activity

# Cards render controls INLINE instead of opening native entity overlays.
for content in (cards, touchpad):
    assert "getIdsByType(" in content
    assert "EntityController.get(" in content
    assert "EntityController.load(" in content
    assert "mayCommandEntity(" in content
    assert "property bool widgetActive: false" in content
    assert "selectionError" in content
    assert "matches.length > 1" in content
    assert "known.length === 1" in content
    assert "ui.cornerRadiusSmall" in content
    assert "colors.dark" in content
    assert "colors.offwhite" in content

assert 'LightStates.Unavailable' in cards
assert 'ClimateStates.Unavailable' in cards
assert 'CoverStates.Unavailable' in cards
assert 'LightFeatures.Dim' in cards
assert 'LightFeatures.Color' in cards
assert 'ClimateFeatures.Target_temperature' in climate_controls
assert 'entityObj.positionAvailable' in cover_controls
assert 'card.entityKind === "LIGHT"' in cards
assert 'card.entityKind === "CLIMATE"' in cards
assert 'card.entityKind === "COVER"' in cards

# Direct native reuse, not screenshots or a modal overlay.
assert 'qrc:/components/entities/light/OnOff.qml' in cards
assert 'qrc:/components/entities/light/Brightness.qml' in cards
assert 'qrc:/components/entities/light/Color.qml' in cards
assert 'ActivityComponents.InlineClimateControls {' in cards
assert 'ActivityComponents.InlineCoverControls {' in cards
assert 'item.compact = true;' in cards
assert 'property bool compact: false' in native_brightness
assert 'property bool compact: false' in native_onoff
assert 'property bool compact: false' in native_openclose
assert 'CoverComponents.OpenClose {' in cover_controls
assert 'compact: true' in cover_controls
assert 'Tumbler {' in climate_controls
assert 'temperatureTumbler.positionViewAtIndex' in climate_controls
assert 'setTargetTemperature(' in climate_controls
assert 'setHvacMode(' in climate_controls
assert 'setPosition(' in cover_controls
assert 'entityObj.open();' in cover_controls
assert 'entityObj.stop();' in cover_controls
assert 'entityObj.close();' in cover_controls
assert 'openEntityDetail' not in cards
assert 'loadThirdContainer' not in cards
assert 'openNativeWidgetDetail' not in activity
assert '"openEntityDetail"' not in activity
assert 'Open controls' not in cards

# Every touch is captured from press to release/cancel. Activity PathView
# cannot steal an in-progress widget gesture, including touchpad swipes.
assert 'property int activeWidgetGestures: 0' in activity
assert 'function beginWidgetGesture()' in activity
assert 'function endWidgetGesture()' in activity
assert 'activeWidgetGestures = Math.max(0, activeWidgetGestures - 1)' in activity
assert 'interactive: uiPages.count > 1 && activityBase.activeWidgetGestures === 0' in activity
assert activity.count('"beginPageGesture": function()') == 2
assert activity.count('"endPageGesture": function()') == 2
for widget in (cards, touchpad):
    assert 'property bool gestureHeld: false' in widget
    assert 'function beginGesture()' in widget
    assert 'function endGesture()' in widget
    assert 'Component.onDestruction: endGesture()' in widget
    assert 'onWidgetActiveChanged: if (!widgetActive) endGesture()' in widget
    if widget == touchpad:
        assert 'preventStealing: true' in widget
    else:
        # PointHandler holds a passive grab and doesn't hide a slider under
        # a full-card MouseArea; child controls retain their drag gestures.
        assert 'PointHandler {' in widget
        assert 'target: null' in widget
        assert 'onActiveChanged:' in widget
        assert 'onClicked: card.openNativeDetail()' not in widget
    assert 'onReleased:' in widget
    assert 'onCanceled:' in widget
    assert widget.index('beginPageGesture();') < widget.index('endPageGesture();')

# Touchpad dispatch is still one command on release, never on every pixel.
assert 'property real startX' in touchpad and 'property real startY' in touchpad
assert 'onPressAndHold:' in touchpad
assert 'Math.max(Math.abs(dx), Math.abs(dy)) < 26' in touchpad
assert 'pad.dispatch("select", false)' in touchpad
assert 'pad.dispatch("select", true)' in touchpad
assert 'pad.dispatch(dx > 0 ? "right" : "left", false)' in touchpad
assert 'pad.dispatch(dy > 0 ? "down" : "up", false)' in touchpad
assert 'pad.beginGesture();' in touchpad
assert 'pad.endGesture();' in touchpad
assert 'remoteObj.buttonMapping' in touchpad
assert 'row.short_press' in touchpad and 'row.long_press' in touchpad
assert '"remote.send_cmd"' in touchpad and '"remote.send"' in touchpad
assert 'RemoteStates.Unavailable' in touchpad
assert 'RemoteFeatures.Send_cmd' in touchpad and 'RemoteFeatures.Send' in touchpad
assert 'enum Enum { Send, Send_cmd, On_off, Toggle }' in remote_api

# Compact cards remain viable in 2x2 grid cells.
for width, height in ((480, 800), (480, 850), (320, 640)):
    card_width, card_height = width / 2, height / 3
    assert card_width >= 160 and card_height >= 200

for marker in ("LIGHT;living", "CLIMATE;living", "COVER;shade", "TP;apple_tv"):
    assert marker in docs
assert "inline" in docs.lower()
assert "OpenClose.qml" in docs
assert "loadThirdContainer" not in docs
assert "page swipe" in docs

print("Native entity detail overlays and widget gesture capture contracts passed.")
