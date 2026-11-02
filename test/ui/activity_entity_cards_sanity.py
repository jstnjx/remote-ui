#!/usr/bin/env python3
"""Static contracts for native Light, Climate and Cover Activity widgets.

Ensure native controls remain embedded in the Activity grid, gesture capture
stays intact, and the removed Touchpad is not registered or bundled.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
activity = (root / "src/qml/components/entities/activity/deviceclass/Activity.qml").read_text()
cards = (root / "src/qml/components/entities/activity/InlineEntityCard.qml").read_text()
climate_controls = (root / "src/qml/components/entities/activity/InlineClimateControls.qml").read_text()
cover_controls = (root / "src/qml/components/entities/activity/InlineCoverControls.qml").read_text()
native_brightness = (root / "src/qml/components/entities/light/Brightness.qml").read_text()
native_onoff = (root / "src/qml/components/entities/light/OnOff.qml").read_text()
native_openclose = (root / "src/qml/components/entities/cover/OpenClose.qml").read_text()
qrc = (root / "resources/qrc/main.qrc").read_text()
docs = (root / "docs/activity-purpose-widgets.md").read_text()

for name in ("InlineEntityCard.qml", "InlineClimateControls.qml", "InlineCoverControls.qml"):
    assert f'alias="components/entities/activity/{name}"' in qrc

for kind in ("LIGHT", "CLIMATE", "COVER"):
    assert f'"{kind}"' in activity
assert 'Qt.createComponent(' in activity
assert 'entitySelector' in activity and 'commandEntityId' in activity
assert 'entityObj.state === ActivityStates.On' in activity
assert 'uiPages.currentIndex === index' in activity
assert 'Power.powerMode === PowerModes.Normal' in activity
assert '"width": gridSizeW * (item.size' in activity
assert '"height": gridSizeH * (item.size' in activity

# The Touchpad must not be compiled, instantiated or advertised anymore.
assert not (root / "src/qml/components/entities/activity/InlineTouchpad.qml").exists()
assert "InlineTouchpad.qml" not in qrc
assert "InlineTouchpad.qml" not in activity
assert 'widgetKind === "TP"' not in activity
assert 'widgetKind === "TOUCHPAD"' not in activity
assert "Touchpad" not in docs
assert "TOUCHPAD" not in docs

# The remaining cards still resolve entities safely and use transparent
# surfaces, not gray backgrounds.
for source in (cards,):
    assert "getIdsByType(" in source
    assert "EntityController.get(" in source
    assert "EntityController.load(" in source
    assert "mayCommandEntity(" in source
    assert "property bool widgetActive: false" in source
    assert "selectionError" in source
    assert "matches.length > 1" in source
    assert "known.length === 1" in source
    assert "color: colors.transparent" in source
    assert "radius: 0" in source
    assert "colors.offwhite" in source

assert "LightStates.Unavailable" in cards
assert "ClimateStates.Unavailable" in cards
assert "CoverStates.Unavailable" in cards
assert "LightFeatures.Dim" in cards
assert "LightFeatures.Color" in cards
assert "ClimateFeatures.Target_temperature" in climate_controls
assert "entityObj.positionAvailable" in cover_controls
for kind in ("LIGHT", "CLIMATE", "COVER"):
    assert f'card.entityKind === "{kind}"' in cards

# Embed native controls directly, without opening a detail overlay.
for name in ("OnOff.qml", "Brightness.qml", "Color.qml"):
    assert f'qrc:/components/entities/light/{name}' in cards
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

# Native control gestures must still win over Activity page swipes.
assert 'property int activeWidgetGestures: 0' in activity
assert 'function beginWidgetGesture()' in activity
assert 'function endWidgetGesture()' in activity
assert 'activeWidgetGestures = Math.max(0, activeWidgetGestures - 1)' in activity
assert 'interactive: uiPages.count > 1 && activityBase.activeWidgetGestures === 0' in activity
assert activity.count('"beginPageGesture": function()') == 1
assert activity.count('"endPageGesture": function()') == 1
assert 'property bool gestureHeld: false' in cards
assert 'function beginGesture()' in cards
assert 'function endGesture()' in cards
assert 'Component.onDestruction: endGesture()' in cards
assert 'onWidgetActiveChanged: if (!widgetActive) endGesture()' in cards
assert 'PointHandler {' in cards
assert 'target: null' in cards
assert 'onActiveChanged:' in cards
assert 'if (active) card.beginGesture();' in cards
assert 'else card.endGesture();' in cards
assert cards.index('beginPageGesture();') < cards.index('endPageGesture();')

for width, height in ((480, 800), (480, 850), (320, 640)):
    card_width, card_height = width / 2, height / 3
    assert card_width >= 160 and card_height >= 200

for marker in ("LIGHT;living", "CLIMATE;living", "COVER;shade"):
    assert marker in docs
assert "inline" in docs.lower()
assert "OpenClose.qml" in docs
assert "transparent" in docs.lower()
assert "loadThirdContainer" not in docs
assert "page swiping" in docs or "page swipe" in docs

print("Native Light Climate Cover Activity widget contracts passed.")
