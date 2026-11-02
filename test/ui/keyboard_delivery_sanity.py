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
assert '"keyboard.text_set", {text: value}' in bridge
assert 'function openManual(mediaId)' in bridge
assert '["KB", "KEYBOARD", "KEYBOARD_SHORTCUT"]' in activity
assert 'keyboardTextPrompt.openManual(target)' in activity
assert 'mediaPlayerIds' in bridge and 'mediaPlayerIds' in settings

# The remote-entity route mirrors the already-working Home Assistant action:
# remote.send_command -> command list containing keyboard.text_set <text>.
assert 'import Entity.Remote 1.0' in bridge
assert 'type !== "media_player" && type !== "remote"' in bridge
assert 'if (type === "remote")' in bridge
assert 'EntityController.onEntityCommand(target.id, "remote.send_cmd",' in bridge
assert '{command: "keyboard.text_set " + value}' in bridge
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
