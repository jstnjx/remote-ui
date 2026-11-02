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
            keyboardBridge.statusMessage = qsTr("No command acknowledgment received. Check Remote and Home Assistant logs.");
            textEntry.showError(qsTr("Text was not confirmed by the Remote Core."));
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
            if (type === "remote") {
                cmd = "remote.send_cmd";
                params = {command: "keyboard.text_set " + value};
            } else if (type === "media_player") {
                const companion = matchingCompanionRemote(target);
                if (companion) {
                    if (!EntityController.mayCommandEntity(companion.enabled)) {
                        statusMessage = qsTr("Companion Remote unavailable: %1").arg(companion.name);
                        blocked = true;
                        continue;
                    }
                    destination = companion;
                    cmd = "remote.send_cmd";
                    params = {command: "keyboard.text_set " + value};
                } else if (isHomeAssistantMediaPlayer(target)) {
                    statusMessage = qsTr("Wrong target: %1 is a Media player. Select its Remote entity.").arg(target.name);
                    blocked = true;
                    continue;
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

        // Do not clear the text or close the popup simply because Core accepted
        // the local API call. Wait for a real Core command acknowledgment, and
        // keep diagnostic feedback visible for troubleshooting failed delivery.
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

    // Hiding the virtual keyboard must not silently discard text. Qt can
    // close the keyboard before delivering its Enter/Send action; the editor
    // remains open with an explicit Send button until submitted or dismissed.


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
            commandTimeout.stop();
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
            commandTimeout.stop();
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

            // Also submit by touch. This is independent of whether the
            // platform's virtual keyboard emits TextField.accepted().
            Components.Button {
                id: explicitSendButton
                width: parent.width - 40
                height: 64
                anchors {
                    top: textEntry.bottom
                    topMargin: 20
                    horizontalCenter: parent.horizontalCenter
                }
                text: qsTr("Send text")
                enabled: !keyboardBridge.sending
                trigger: function() { keyboardBridge.submitText(); }
            }

            Text {
                id: deliveryStatus
                anchors {
                    top: explicitSendButton.bottom
                    topMargin: 12
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
