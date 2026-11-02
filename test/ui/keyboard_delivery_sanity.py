#!/usr/bin/env python3
"""Static regression contracts for keyboard Enter, routing, and Apple TV text.

The native Apple TV Keyboard integration implements media-player SEARCH_MEDIA,
which invokes pyatv.keyboard.text_set. A physical integration test is still
required to confirm the Companion pairing and tvOS focus state.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
style = (ROOT / "src/qml/keyboard/QtQuick/VirtualKeyboard/Styles/remotestyle/style.qml").read_text()
bridge = (ROOT / "src/qml/components/entities/activity/KeyboardTextPrompt.qml").read_text()
settings = (ROOT / "src/qml/settings/settings/KeyboardPrompt.qml").read_text()
activity = (ROOT / "src/qml/components/entities/activity/deviceclass/Activity.qml").read_text()
media_header = (ROOT / "src/ui/entity/mediaPlayer.h").read_text()
media_cpp = (ROOT / "src/ui/entity/mediaPlayer.cpp").read_text()
docs = (ROOT / "docs/sensor-keyboard.md").read_text()
mapping = (ROOT / "resources/icons/icon-mapping.json").read_text()
qrc = (ROOT / "resources/qrc/keyboard.qrc").read_text()

# Native Send arrow, no duplicate button; dismissal closes the full overlay.
assert "Components.Icon {" in style
assert 'return "uc:arrow-turn-down"' in style
assert '"arrow-turn-down"' in mapping
assert 'size: 60' in style
assert 'images/enter-868482.svg' not in style
assert 'root.keyboardSendMode ? ""' in style
assert 'Styles/remotestyle/style.qml' in qrc
assert 'id: explicitSendButton' not in bridge
assert 'sendOnEnter: true' in bridge
assert 'function onAccepted() { keyboardBridge.submitText(); }' in bridge
assert 'if (textPopup.opened && !keyboardBridge.closingKeyboard)' in bridge
assert 'onClosed:' in bridge

# The manual KB widget and saved per-activity rules still target configured
# entities; a native keyboard player overrides old HA Remote selections.
assert 'function openManual(entityId)' in bridge
assert 'keyboardTextPrompt.openManual(target)' in activity
assert '["KB", "KEYBOARD", "KEYBOARD_SHORTCUT"]' in activity
assert 'const target = explicitId || ruleTarget || commandId ||' in activity
assert 'id.indexOf("appletv_keyboard") >= 0' in activity
assert 'homeAssistantWebhookUrl' not in bridge
assert 'mediaPlayerIds' in bridge
assert 'configuredTargets.filter(function(id)' in bridge
assert 'const targets = keyboardTargets.length ? keyboardTargets : configuredTargets;' in bridge

# Use the media player search feature, which already has full result/error
# feedback and is connected to a native Apple TV Keyboard integration.
assert 'function isNativeAppleTVKeyboard(target)' in bridge
assert 'function matchingNativeKeyboard(target)' in bridge
assert 'candidateName !== wanted' in bridge
assert 'return result;' in bridge
assert 'cmd = "native.search";' in bridge
assert 'nativePlayer.searchMedia(value, "", "", [], 10, 1);' in bridge
assert 'target: keyboardBridge.pendingSearchTarget' in bridge
assert 'function onSearchMediaResult(items, pagination)' in bridge
assert 'function onSearchMediaError(code, message)' in bridge
assert 'title.indexOf("Text not sent") === 0' in bridge
assert 'showKeyboardDeliveryError(' in bridge
assert 'keyboardBridge.pendingSearchTarget = null;' in bridge
assert 'if (!pendingSearchTarget) {' in bridge
assert 'Q_INVOKABLE void searchMedia(' in media_header
assert 'emit searchMediaRequested(m_id, params);' in media_cpp
assert 'emit searchMediaResult(list, paginationToVariant(pagination));' in media_cpp
assert 'emit searchMediaError(code, message);' in media_cpp

# The picker distinguishes the special bridge from ordinary media players;
# no valid Apple TV text is sent using Home Assistant remote.send_command.
assert 'qsTr("Apple TV Keyboard: ")' in settings
assert 'qsTr("Media player: ")' in settings
assert 'qsTr("Remote: ")' in settings
assert 'Select the Apple TV Keyboard media player in Keyboard settings.' in bridge
assert 'isHomeAssistantEntity(target)' in bridge
assert 'remote.send_command' in docs
assert 'pyatv.keyboard.text_set' in docs
assert 'apple_tv.set_keyboard_text' in docs
assert 'api/webhook' not in docs
assert 'XMLHttpRequest' not in bridge

# Other integrations retain original native commands and Core diagnostics.
assert 'cmd = "remote.send_cmd";' in bridge
assert 'cmd = "keyboard.text_set";' in bridge
assert 'params = {text: value};' in bridge
assert 'EntityController.onEntityCommand(request.entityId, request.command, request.params);' in bridge
assert 'function onEntityCommandResult(entityId, command, success, errorCode, errorMessage)' in bridge
assert 'id: commandTimeout' in bridge

print("Keyboard Send/close and native Apple TV Keyboard Search route checks passed.")
