#!/usr/bin/env python3
"""Regression checks for native Send icon and Apple TV text delivery.

Static source-contract checks only. An actual HA Apple TV must still be
tested with a focused text field on its screen.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
style = (ROOT / "src/qml/keyboard/QtQuick/VirtualKeyboard/Styles/remotestyle/style.qml").read_text()
bridge = (ROOT / "src/qml/components/entities/activity/KeyboardTextPrompt.qml").read_text()
settings = (ROOT / "src/qml/settings/settings/KeyboardPrompt.qml").read_text()
docs = (ROOT / "docs/sensor-keyboard.md").read_text()
mapping = (ROOT / "resources/icons/icon-mapping.json").read_text()
fallback = (ROOT / "resources/icons/icon-fallback.json").read_text()
qrc = (ROOT / "resources/qrc/keyboard.qrc").read_text()

# Missing relative keyboard SVGs must never be used for Send. The icon is
# bundled in the same font as every other native Remote icon.
assert "Components.Icon {" in style
assert 'return "uc:arrow-turn-down"' in style
assert '"arrow-turn-down"' in mapping
assert 'images/enter-868482.svg' not in style
assert 'images/check-868482.svg' not in style
assert 'images/search-868482.svg' not in style
assert 'enterKeyText.text.length === 0' in style
assert 'root.keyboardSendMode ? ""' in style
assert 'Styles/remotestyle/style.qml' in qrc

# The native command remains for integrations that implement it.
assert 'EntityController.onEntityCommand(target.id, "keyboard.text_set", {text: value})' in bridge
assert 'keyboard.text_set' in docs

# HA's Apple TV action is not a UC media-player entity command. A selected
# rule provides a local bridge; manual KB widgets inherit the same rule.
for required in (
    'homeAssistantWebhookUrl',
    'selected.indexOf(mediaId) >= 0',
    'function submitViaHomeAssistant(url, value)',
    'request.open("POST", endpoint)',
    'request.setRequestHeader("Content-Type", "application/json")',
    'request.send(JSON.stringify({text: value}))',
    'request.status >= 200 && request.status < 300',
    'request.readyState !== 4',
    'if (submitting) return',
    'submitSerial++',
    'submitTimeout.stop()',
    'submitTimeout.restart()',
    'textEntry.showError',
    'homeAssistantTarget',
    '!keyboardBridge.submitting',
):
    assert required in bridge, f"Keyboard bridge missing: {required}"

for required in (
    'editRule("homeAssistantWebhookUrl", webhookInput.inputValue.trim())',
    'property',  # page still uses ordinary setting and navigational props
    'id: webhookInput',
    'id: saveWebhookButton',
    'navDown: saveWebhookButton',
):
    assert required in settings, f"Keyboard settings missing: {required}"

assert "apple_tv.set_keyboard_text" in docs
assert "trigger: webhook" in docs
assert "local_only: true" in docs
assert "config_entry_id:" in docs
assert '{{ trigger.json.text }}' in docs
assert "random" in docs.lower()
assert "No selected media player" in bridge

# The HA service is bound to one configured Apple TV entry rather than
# accepting device IDs or service names from an untrusted POST body.
assert 'JSON.stringify({text: value})' in bridge
assert "config_entry_id: YOUR_APPLE_TV_CONFIG_ENTRY_ID" in docs
assert '"service":' not in bridge

print("Keyboard Send icon, HA text bridge and error-state contracts passed.")
