#!/usr/bin/env python3
"""Static contracts for native Send glyph and direct Apple TV remote text.

A device-and-Home-Assistant integration test is still needed to confirm actual
text entry on a focused Apple TV text field.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
style = (ROOT / "src/qml/keyboard/QtQuick/VirtualKeyboard/Styles/remotestyle/style.qml").read_text()
bridge = (ROOT / "src/qml/components/entities/activity/KeyboardTextPrompt.qml").read_text()
settings = (ROOT / "src/qml/settings/settings/KeyboardPrompt.qml").read_text()
activity = (ROOT / "src/qml/components/entities/activity/deviceclass/Activity.qml").read_text()
docs = (ROOT / "docs/sensor-keyboard.md").read_text()
mapping = (ROOT / "resources/icons/icon-mapping.json").read_text()
qrc = (ROOT / "resources/qrc/keyboard.qrc").read_text()

# The bundled native icon font replaces missing keyboard SVG artwork.
assert "Components.Icon {" in style
assert 'return "uc:arrow-turn-down"' in style
assert '"arrow-turn-down"' in mapping
assert 'images/enter-868482.svg' not in style
assert 'images/check-868482.svg' not in style
assert 'images/search-868482.svg' not in style
assert 'enterKeyText.text.length === 0' in style
assert 'root.keyboardSendMode ? ""' in style
assert 'Styles/remotestyle/style.qml' in qrc

# All native media-player keyboard rules and manual shortcuts remain supported.
assert 'cmd = "keyboard.text_set";' in bridge
assert 'params = {text: value};' in bridge
assert 'function openManual(entityId)' in bridge
assert '["KB", "KEYBOARD", "KEYBOARD_SHORTCUT"]' in activity
assert 'keyboardTextPrompt.openManual(target)' in activity
assert 'const target = explicitId || ruleTarget || commandId ||' in activity
assert 'candidate.type === EntityTypes.Remote' in activity
assert 'ui.createNotification(qsTr("Select an Apple TV Remote' in activity
assert 'function matchingCompanionRemote(mediaPlayer)' in bridge
assert 'String(mediaPlayer.id).replace(".media_player.", ".remote.")' in bridge
assert 'function isHomeAssistantMediaPlayer(target)' in bridge
assert 'const companion = matchingCompanionRemote(target)' in bridge
assert 'Select the Apple TV Remote entity, not its media player' in bridge
assert 'id: explicitSendButton' in bridge
assert 'trigger: function() { keyboardBridge.submitText(); }' in bridge
assert 'function onAccepted() { keyboardBridge.submitText(); }' in bridge
assert 'onClosed()' not in bridge  # virtual keyboard hides without dismissing text popup
assert 'size: 60' in style
assert 'Math.round(112 * scaleHint)' not in style
assert 'property bool sending: false' in bridge
assert 'id: commandTimeout' in bridge
assert 'function onEntityCommandResult(entityId, command, success, errorCode, errorMessage)' in bridge
assert 'statusMessage = qsTr("Sending via %1 to %2 (%3)")' in bridge
assert 'keyboardBridge.statusMessage = qsTr("Core rejected %1 (%2): %3")' in bridge
assert 'Core accepted command for %1' in bridge
assert 'request.entityId, request.command, request.params' in bridge
assert 'if (sending) return;' in bridge
assert 'enabled: !keyboardBridge.sending' in bridge
assert 'id: deliveryStatus' in bridge
assert 'keyboardBridge.statusMessage' in bridge
controller_h = (ROOT / "src/ui/entity/entityController.h").read_text()
controller_cpp = (ROOT / "src/ui/entity/entityController.cpp").read_text()
assert 'void entityCommandResult(QString entityId, QString command, bool success,' in controller_h
assert 'emit entityCommandResult(entityId, command, true, 0, QString());' in controller_cpp
assert 'emit entityCommandResult(live.entityId, live.command, false, code, message);' in controller_cpp


assert 'mediaPlayerIds' in bridge and 'mediaPlayerIds' in settings

# The remote-entity route mirrors the already-working Home Assistant action:
# remote.send_command -> command list containing keyboard.text_set <text>.
assert 'import Entity.Remote 1.0' in bridge
assert 'type !== "media_player" && type !== "remote"' in bridge
assert 'if (type === "remote")' in bridge
assert 'cmd = "remote.send_cmd";' in bridge
assert 'EntityController.onEntityCommand(request.entityId, request.command, request.params);' in bridge
assert 'params = {command: "keyboard.text_set " + value};' in bridge
assert 'EntityController.mayCommandEntity(target.enabled)' in bridge
assert 'EntityController.getIdsByType("remote")' in settings
assert 'EntityController.getIdsByType("media_player")' in settings
assert 'qsTr("Remote: ")' in settings
assert 'qsTr("Text input targets")' in settings
assert 'remote.send_cmd' in docs
assert 'remote.send_command' in docs
assert 'remote.apple_tv_4k_wohnzimmer_gen_2' in docs
assert '"keyboard.text_set Hello from UC Remote"' in docs

# There is no webhook or token dependency for this already supported route.
assert 'homeAssistantWebhookUrl' not in bridge
assert 'homeAssistantWebhookUrl' not in settings
assert 'XMLHttpRequest' not in bridge
assert 'webhook' not in bridge.lower()
assert 'api/webhook' not in docs

print("Native Send icon and direct Apple TV remote text contracts passed.")
