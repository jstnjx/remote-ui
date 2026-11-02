// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.VirtualKeyboard 2.3
import Config 1.0
import Entity.Controller 1.0
import Entity.Remote 1.0
import "qrc:/components" as Components

// Per-activity, multi-sensor keyboard automation. Sensors need not appear in
// activity.includedEntities; the page widgets and configured sensor IDs work.
Item {
    id: keyboardBridge
    width: 0
    height: 0

    property string activityId: ""
    property bool activityActive: false
    property var prompted: ({})
    property var activeRule: null
    property bool manualMode: false
    property bool closingKeyboard: false
    property bool sending: false
    // Search results are delivered asynchronously by the native Apple TV
    // Keyboard media-player integration, after the on-screen keyboard closes.
    property var pendingSearchTarget: null
    property var pendingTargetIds: []
    property int succeededCommands: 0
    property string statusMessage: ""
    property string pendingManualTarget: ""
    property string currentPrompt: qsTr("Enter text on the selected device?")

    readonly property var rules: Config.keyboardRules.filter(function(rule) {
        return rule.activityId === activityId;
    })
    readonly property var watchedSensorIds: {
        const ids = [];
        for (let i = 0; i < rules.length; ++i) {
            const sensors = rules[i].sensorIds || [];
            for (let j = 0; j < sensors.length; ++j) {
                if (ids.indexOf(sensors[j]) < 0) ids.push(sensors[j]);
            }
        }
        return ids;
    }

    function ruleKey(rule) {
        return rule.id || rule.activityId;
    }

    function ruleOn(rule) {
        const sensors = rule.sensorIds || [];
        for (let i = 0; i < sensors.length; ++i) {
            const sensor = EntityController.get(sensors[i]);
            if (sensor && sensor.getTypeAsString() === "sensor" &&
                    String(sensor.rawValue).trim().toLowerCase() === "on") return true;
        }
        return false;
    }

    function evaluate() {
        if (!activityActive) {
            offerPopup.close();
            textPopup.close();
            return;
        }
        // Keep the currently entered text stable until its popup closes.
        for (let i = 0; i < rules.length; ++i) {
            const rule = rules[i];
            const key = ruleKey(rule);
            if (!ruleOn(rule)) {
                if (prompted[key]) {
                    const updated = Object.assign({}, prompted);
                    delete updated[key];
                    prompted = updated;
                }
                if (activeRule && ruleKey(activeRule) === key) {
                    offerPopup.close();
                    textPopup.close();
                    activeRule = null;
                }
                continue;
            }
            if (!prompted[key] && !offerPopup.opened && !textPopup.opened &&
                    (rule.mediaPlayerIds || []).length > 0) {
                const updated = Object.assign({}, prompted);
                updated[key] = true;
                prompted = updated;
                activeRule = rule;
                currentPrompt = rule.prompt || qsTr("Enter text on the media player?");
                offerPopup.menuItems = [{
                    title: qsTr("Open keyboard"),
                    icon: "uc:keyboard",
                    callback: function() { textPopup.open(); }
                }];
                offerPopup.open();
                break;
            }
        }
    }

    // Called by a keyboard shortcut Text Button. Targets may be a Remote
    // entity or a media player; manual invocation needs no sensor.
    function openManual(entityId) {
        if (!activityActive) {
            ui.createNotification(qsTr("Start the activity before using the keyboard"), true);
            return;
        }
        if (!entityId) {
            ui.createNotification(qsTr("Select an Apple TV Remote under Keyboard input automation"), true);
            return;
        }
        const target = EntityController.get(entityId);
        if (!target) {
            pendingManualTarget = entityId;
            EntityController.load(entityId);
            return;
        }
        const type = target.getTypeAsString();
        if (type !== "media_player" && type !== "remote") {
            ui.createNotification(qsTr("Keyboard target must be a Remote or Media player"), true);
            return;
        }
        pendingManualTarget = "";
        manualMode = true;
        activeRule = {id: "manual", mediaPlayerIds: [entityId]};
        textPopup.open();
    }

    function matchingCompanionRemote(mediaPlayer) {
        if (!mediaPlayer || !mediaPlayer.id) return null;
        // Both entities from the same HA integration use the same suffix:
        // integration.main.media_player.apple_tv -> integration.main.remote.apple_tv
        const remoteId = String(mediaPlayer.id).replace(".media_player.", ".remote.");
        if (remoteId === mediaPlayer.id) return null;
        const remote = EntityController.get(remoteId);
        return remote && remote.getTypeAsString() === "remote" ? remote : null;
    }

    function isNativeAppleTVKeyboard(target) {
        if (!target || target.getTypeAsString() !== "media_player") return false;
        const id = String(target.id || "").toLowerCase();
        const integration = String(target.integrationId || "").toLowerCase();
        const name = String(target.name || "").toLowerCase();
        return integration.indexOf("appletv_keyboard") >= 0 ||
               id.indexOf("appletv_keyboard") >= 0 ||
               name.indexOf("apple tv keyboard -") === 0;
    }

    function isHomeAssistantEntity(target) {
        if (!target) return false;
        const id = String(target.id || "").toLowerCase();
        const integration = String(target.integrationId || "").toLowerCase();
        return /home[_-]?assistant|homeassistant/.test(id) ||
               /home[_-]?assistant|homeassistant/.test(integration);
    }

    function normalizeAppleTVName(name) {
        return String(name || "").toLowerCase()
            .replace(/^apple\\s*tv\\s*keyboard\\s*[-:–]\\s*/, "")
            .replace(/[^a-z0-9]+/g, "");
    }

    function matchingNativeKeyboard(target) {
        if (isNativeAppleTVKeyboard(target)) return target;
        if (!target) return null;
        const wanted = normalizeAppleTVName(target.name);
        if (!wanted) return null;
        const ids = EntityController.getIdsByType("media_player") || [];
        let result = null;
        for (let i = 0; i < ids.length; ++i) {
            const candidate = EntityController.get(ids[i]);
            if (!isNativeAppleTVKeyboard(candidate)) continue;
            const candidateName = normalizeAppleTVName(candidate.name);
            if (!candidateName || candidateName !== wanted) continue;
            if (result && result.id !== candidate.id) return null;
            result = candidate;
        }
        return result;
    }

    function showKeyboardDeliveryError(message) {
        statusMessage = message;
        if (textPopup.opened)
            textEntry.showError(message);
        else
            ui.createNotification(message, true);
    }

    function isHomeAssistantMediaPlayer(target) {
        const id = String(target.id || "").toLowerCase();
        const integration = String(target.integrationId || "").toLowerCase();
        return /home[_-]?assistant|homeassistant/.test(id) ||
               /home[_-]?assistant|homeassistant/.test(integration);
    }

    Timer {
        id: commandTimeout
        interval: 14000
        repeat: false
        onTriggered: {
            if (!keyboardBridge.sending) return;
            keyboardBridge.sending = false;
            keyboardBridge.pendingTargetIds = [];
            if (keyboardBridge.pendingSearchTarget) {
                keyboardBridge.pendingSearchTarget = null;
                keyboardBridge.showKeyboardDeliveryError(qsTr("Apple TV Keyboard did not respond. Check its connection."));
                return;
            }
            keyboardBridge.showKeyboardDeliveryError(qsTr("No command acknowledgment received. Check Remote and Home Assistant logs."));
        }
    }

    function submitText() {
        if (sending) return;
        if (!activityActive || !activeRule || (!manualMode && !ruleOn(activeRule))) {
            textEntry.showError(qsTr("The activity or sensor is no longer active."));
            return;
        }
        // Grab the text before the virtual keyboard changes focus or hides.
        const value = textEntry.inputValue;
        if (value.length === 0) {
            textEntry.showError(qsTr("Enter some text first."));
            return;
        }

        const targets = activeRule.mediaPlayerIds || [];
        const requests = [];
        const seen = {};
        let blocked = false;

        for (let i = 0; i < targets.length; ++i) {
            const target = EntityController.get(targets[i]);
            if (!target) {
                statusMessage = qsTr("Target not loaded: %1").arg(targets[i]);
                blocked = true;
                continue;
            }
            if (!EntityController.mayCommandEntity(target.enabled)) {
                statusMessage = qsTr("Target unavailable: %1").arg(target.name);
                blocked = true;
                continue;
            }

            let destination = target;
            let cmd = "";
            let params = ({});
            const type = target.getTypeAsString();
            if (isNativeAppleTVKeyboard(target)) {
                cmd = "native.search";
                params = {query: value};
            } else if (type === "remote" || type === "media_player") {
                const nativeKeyboard = matchingNativeKeyboard(target);
                if (nativeKeyboard) {
                    if (!EntityController.mayCommandEntity(nativeKeyboard.enabled)) {
                        statusMessage = qsTr("Apple TV Keyboard integration is unavailable: %1").arg(nativeKeyboard.name);
                        blocked = true;
                        continue;
                    }
                    destination = nativeKeyboard;
                    cmd = "native.search";
                    params = {query: value};
                } else if (isHomeAssistantEntity(target)) {
                    statusMessage = qsTr("Home Assistant Apple TV Remote cannot send text. Select the Apple TV Keyboard media player in Keyboard settings.");
                    blocked = true;
                    continue;
                } else if (type === "remote") {
                    cmd = "remote.send_cmd";
                    params = {command: "keyboard.text_set " + value};
                } else {
                    cmd = "keyboard.text_set";
                    params = {text: value};
                }
            } else {
                statusMessage = qsTr("Unsupported keyboard target: %1").arg(target.name);
                blocked = true;
                continue;
            }
            if (seen[destination.id]) continue;
            seen[destination.id] = true;
            requests.push({entityId: destination.id, name: destination.name, command: cmd, params: params});
        }
        if (blocked || requests.length === 0) {
            if (!statusMessage)
                statusMessage = qsTr("No usable target. Choose the Apple TV Remote in Keyboard settings.");
            textEntry.showError(statusMessage);
            return;
        }

        // Native Apple TV Keyboard uses the existing media-player search
        // operation, backed by pyatv.keyboard.text_set. This is NOT the Home
        // Assistant remote.send_command action, which rejects keyboard.text_set.
        if (requests.length === 1 && requests[0].command === "native.search") {
            const nativePlayer = EntityController.get(requests[0].entityId);
            if (!nativePlayer || !nativePlayer.searchMedia) {
                showKeyboardDeliveryError(qsTr("Apple TV Keyboard search is unavailable."));
                return;
            }
            pendingSearchTarget = nativePlayer;
            pendingTargetIds = [];
            succeededCommands = 0;
            sending = true;
            statusMessage = qsTr("Sending text through %1").arg(nativePlayer.name);
            commandTimeout.restart();
            console.log("Apple TV keyboard search dispatched to", nativePlayer.id);
            nativePlayer.searchMedia(value, "", "", [], 10, 1);
            keyboard.hide();
            return;
        }
        if (requests.some(function(request) { return request.command === "native.search"; })) {
            showKeyboardDeliveryError(qsTr("Select only one Apple TV Keyboard target for text entry."));
            return;
        }

        pendingTargetIds = requests.map(function(request) { return request.entityId; });
        succeededCommands = 0;
        sending = true;
        statusMessage = qsTr("Sending via %1 to %2 (%3)")
                        .arg(requests[0].command).arg(requests[0].name).arg(requests[0].entityId);
        commandTimeout.restart();
        for (let j = 0; j < requests.length; ++j) {
            const request = requests[j];
            console.log("Keyboard submitting to entity:", request.entityId, request.command);
            EntityController.onEntityCommand(request.entityId, request.command, request.params);
        }
    }

    onActivityActiveChanged: evaluate()
    onActivityIdChanged: { prompted = ({}); evaluate(); }
    onRulesChanged: evaluate()
    Component.onCompleted: evaluate()

    Connections {
        target: keyboardBridge.pendingSearchTarget
        ignoreUnknownSignals: true

        function onSearchMediaResult(items, pagination) {
            if (!keyboardBridge.pendingSearchTarget) return;
            commandTimeout.stop();
            keyboardBridge.sending = false;
            keyboardBridge.pendingSearchTarget = null;
            const first = items && items.length ? items[0] : null;
            const title = first ? String(first.title || "") : "";
            if (!first || title.indexOf("Text not sent") === 0 ||
                    title.indexOf("keyboard-not-sent") >= 0) {
                keyboardBridge.showKeyboardDeliveryError(
                    first && first.subtitle ? String(first.subtitle)
                                            : qsTr("Apple TV Keyboard did not confirm text entry."));
            } else {
                keyboardBridge.statusMessage = qsTr("Text delivered through Apple TV Keyboard.");
                console.log("Apple TV Keyboard confirmed text entry");
            }
        }
        function onSearchMediaError(code, message) {
            if (!keyboardBridge.pendingSearchTarget) return;
            commandTimeout.stop();
            keyboardBridge.sending = false;
            keyboardBridge.pendingSearchTarget = null;
            keyboardBridge.showKeyboardDeliveryError(
                qsTr("Apple TV Keyboard error %1: %2").arg(code).arg(message));
        }
    }

    Connections {
        target: EntityController

        function onEntityCommandResult(entityId, command, success, errorCode, errorMessage) {
            if (!keyboardBridge.sending || !textPopup.opened ||
                    (command !== "remote.send_cmd" && command !== "keyboard.text_set"))
                return;
            const index = keyboardBridge.pendingTargetIds.indexOf(entityId);
            if (index < 0) return;

            const remaining = keyboardBridge.pendingTargetIds.slice();
            remaining.splice(index, 1);
            keyboardBridge.pendingTargetIds = remaining;
            if (!success) {
                keyboardBridge.statusMessage = qsTr("Core rejected %1 (%2): %3")
                    .arg(entityId).arg(errorCode).arg(errorMessage);
                textEntry.showError(keyboardBridge.statusMessage);
            } else {
                keyboardBridge.succeededCommands++;
                keyboardBridge.statusMessage = qsTr("Core accepted command for %1. If text is absent on Apple TV, check the Home Assistant integration logs.").arg(entityId);
            }
            if (remaining.length === 0) {
                commandTimeout.stop();
                keyboardBridge.sending = false;
            }
        }

        function onEntityLoaded(success, entityId) {
            if (!success) return;
            if (entityId === keyboardBridge.pendingManualTarget) {
                keyboardBridge.openManual(entityId);
            }
            if (keyboardBridge.watchedSensorIds.indexOf(entityId) >= 0) keyboardBridge.evaluate();
        }
    }

    // Observe changes to every chosen sensor, even when it does not appear in
    // the activity's includedEntities list.
    Repeater {
        model: keyboardBridge.watchedSensorIds
        delegate: Item {
            width: 0
            height: 0
            property var sensorObj: EntityController.get(modelData)
            Connections {
                target: sensorObj
                ignoreUnknownSignals: true
                function onValueChanged() { keyboardBridge.evaluate(); }
            }
            Connections {
                target: EntityController
                function onEntityLoaded(success, entityId) {
                    if (success && entityId === modelData) {
                        sensorObj = EntityController.get(entityId);
                        keyboardBridge.evaluate();
                    }
                }
            }
        }
    }

    // The popup belongs to the virtual keyboard. When the keyboard is
    // dismissed via its native Close action, Back or another UI action,
    // remove the full-screen overlay as well. The guard prevents the popup's
    // own onClosed -> keyboard.hide() cleanup from re-entering this handler.
    Connections {
        target: keyboard
        function onClosed() {
            if (textPopup.opened && !keyboardBridge.closingKeyboard)
                textPopup.close();
        }
    }

    // Reuse the remote's existing menu popup for the one-time question.
    Components.PopupMenu {
        id: offerPopup
        parent: Overlay.overlay
        title: keyboardBridge.currentPrompt
    }

    // InputField uses the remote's existing Qt Virtual Keyboard and keyboard
    // layout. The input stays above the on-screen keyboard.
    Popup {
        id: textPopup
        parent: Overlay.overlay
        width: parent.width
        height: parent.height
        x: 0
        y: 0
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape

        background: Rectangle {
            color: colors.black
        }

        onOpened: {
            if (!pendingSearchTarget) commandTimeout.stop();
            sending = false;
            pendingTargetIds = [];
            statusMessage = "";
            root.keyboardSendMode = true;
            closingKeyboard = false;
            textEntry.inputValue = "";
            keyboardNavigation.takeControl();
            Qt.callLater(function() {
                if (textPopup.opened) {
                    textEntry.inputField.forceActiveFocus();
                    keyboard.show();
                }
            });
        }

        onClosed: {
            if (!pendingSearchTarget) commandTimeout.stop();
            sending = false;
            pendingTargetIds = [];
            statusMessage = "";
            closingKeyboard = true;
            root.keyboardSendMode = false;
            manualMode = false;
            keyboard.hide();
            keyboardNavigation.releaseControl();
            textEntry.inputValue = "";
        }

        Components.ButtonNavigation {
            id: keyboardNavigation
            defaultConfig: {
                "BACK": {
                    "pressed": function() { textPopup.close(); }
                },
                "HOME": {
                    "pressed": function() { textPopup.close(); }
                }
            }
        }

        contentItem: Item {
            Components.TitleBar {
                id: inputTitle
                text: qsTr("Send text")
                action: "close"
                goBack: function() { textPopup.close(); }
            }

            Components.InputField {
                id: textEntry
                width: parent.width - 40
                anchors { top: inputTitle.bottom; topMargin: 12; horizontalCenter: parent.horizontalCenter }
                moveInput: false
                keyboardFollowsFocus: true
                label: qsTr("Text")
                inputField.placeholderText: qsTr("Enter text")
                sendOnEnter: true

                Connections {
                    target: textEntry.inputField
                    function onAccepted() { keyboardBridge.submitText(); }
                }
            }

            Text {
                id: deliveryStatus
                anchors {
                    top: textEntry.bottom
                    topMargin: 14
                    left: parent.left
                    right: parent.right
                    leftMargin: 20
                    rightMargin: 20
                }
                text: keyboardBridge.statusMessage
                visible: text.length > 0
                color: colors.textSecondary
                wrapMode: Text.WordWrap
                font: fonts.help()
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }
    }
}
