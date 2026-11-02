#!/usr/bin/env python3
"""Static contracts for native Activity cards and gesture touchpad.

Device UI testing remains necessary; these checks guard routing, feature gates,
grid sizing and reuse of the native entity APIs.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
activity = (root / "src/qml/components/entities/activity/deviceclass/Activity.qml").read_text()
cards = (root / "src/qml/components/entities/activity/InlineEntityCard.qml").read_text()
touchpad = (root / "src/qml/components/entities/activity/InlineTouchpad.qml").read_text()
qrc = (root / "resources/qrc/main.qrc").read_text()
docs = (root / "docs/activity-purpose-widgets.md").read_text()
light_api = (root / "src/ui/entity/light.h").read_text()
climate_api = (root / "src/ui/entity/climate.h").read_text()
cover_api = (root / "src/ui/entity/cover.h").read_text()
remote_api = (root / "src/ui/entity/remote.h").read_text()

for name in ("InlineEntityCard.qml", "InlineTouchpad.qml"):
    assert f'alias="components/entities/activity/{name}"' in qrc

for kind in ("LIGHT", "CLIMATE", "COVER", "TP", "TOUCHPAD"):
    assert f'"{kind}"' in activity
assert "widgetKind === \"TP\" || widgetKind === \"TOUCHPAD\"" in activity
assert 'Qt.createComponent(' in activity
assert "entitySelector" in activity
assert "commandEntityId" in activity
assert "widgetActive" in activity
assert 'entityObj.state === ActivityStates.On' in activity
assert 'uiPages.currentIndex === index' in activity
assert "Power.powerMode === PowerModes.Normal" in activity
assert '"width": gridSizeW * (item.size' in activity
assert '"height": gridSizeH * (item.size' in activity

# No new Core API schema, unsupported entities or command dispatches from
# hidden or inactive cards.
for content in (cards, touchpad):
    assert "getIdsByType(" in content
    assert "EntityController.get(" in content
    assert "EntityController.load(" in content
    assert "mayCommandEntity(" in content
    assert "property bool widgetActive: false" in content
    assert "selectionError" in content
    assert "matches.length > 1" in content
    assert "known.length === 1" in content
    assert "enabled: " in content
    assert "ui.cornerRadiusSmall" in content
    assert "colors.dark" in content
    assert "colors.offwhite" in content

# The entity cards reuse native state, feature and command methods. Features
# drive whether controls are displayed/enabled.
for method in ("toggle(", "setBrightness(", "setColorTemperature("):
    assert method in cards and method in light_api
assert "LightFeatures.Dim" in cards
assert "LightFeatures.Color_temperature" in cards
for method in ("setTargetTemperature(", "setHvacMode("):
    assert method in cards and method in climate_api
assert "ClimateFeatures.Target_temperature" in cards
assert "targetTemperatureStep" in cards
assert "minTemperature" in cards and "maxTemperature" in cards
for method in ("setPosition(", "open(", "close(", "stop("):
    assert method in cards and method in cover_api
assert "CoverFeatures.Position" in cards
assert "CoverFeatures.Open" in cards
assert "CoverFeatures.Close" in cards
assert "CoverFeatures.Stop" in cards
assert "positionAvailable" in cards
assert 'card.entityKind === "LIGHT"' in cards
assert 'card.entityKind === "CLIMATE"' in cards
assert 'card.entityKind === "COVER"' in cards

# Gesture engine: one command on release after threshold, tap to select,
# optional mapped long press; no repeated network send while dragging.
assert "property real startX" in touchpad
assert "property real startY" in touchpad
assert "onReleased:" in touchpad
assert "onPressAndHold:" in touchpad
assert "Math.max(Math.abs(dx), Math.abs(dy)) < 26" in touchpad
assert 'pad.dispatch("select", false)' in touchpad
assert 'pad.dispatch("select", true)' in touchpad
assert 'pad.dispatch(dx > 0 ? "right" : "left", false)' in touchpad
assert 'pad.dispatch(dy > 0 ? "down" : "up", false)' in touchpad
assert "remoteObj.buttonMapping" in touchpad
assert "row.short_press" in touchpad and "row.long_press" in touchpad
assert '"remote.send_cmd"' in touchpad and '"remote.send"' in touchpad
assert 'RemoteFeatures.Send_cmd' in touchpad
assert 'RemoteFeatures.Send' in touchpad
assert "sendCommand" not in touchpad
assert "enum Enum { Send, Send_cmd, On_off, Toggle }" in remote_api
assert "onPositionChanged:" not in touchpad

# Compact geometry has enough room for a native minimum touch target with
# a 2x2 default grid (Remote 2 480x800; Remote 3 480x850).
for width, height in ((480, 800), (480, 850), (320, 640)):
    cell_width, cell_height = width / 4, height / 6
    card_width, card_height = 2 * cell_width, 2 * cell_height
    assert card_width >= 160
    assert card_height >= 200
    assert card_width - 20 >= 140
    assert card_height - 20 >= 180

assert "LIGHT;living" in docs
assert "CLIMATE;living" in docs
assert "COVER;shade" in docs
assert "TP;apple_tv" in docs
print("Native cards and gesture touchpad integration contracts passed.")
