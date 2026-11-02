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

    function submitText() {
        if (!activityActive || !activeRule || (!manualMode && !ruleOn(activeRule))) {
            textEntry.showError(qsTr("The activity or sensor is no longer active."));
            return;
        }
        const value = textEntry.inputValue;
        if (value.length === 0) {
            textEntry.showError(qsTr("Enter some text first."));
            return;
        }
        // Retain the existing saved field name for backwards compatibility.
        // Both media_player and remote entities are valid targets.
        const targets = activeRule.mediaPlayerIds || [];
        let sent = 0;
        let hasWrongAppleTvTarget = false;
        for (let i = 0; i < targets.length; ++i) {
            const target = EntityController.get(targets[i]);
            if (!target || !EntityController.mayCommandEntity(target.enabled))
                continue;

            const type = target.getTypeAsString();
            if (type === "remote") {
                // UC HA maps remote.send_cmd to Home Assistant's
                // remote.send_command; the value must be one command string.
                EntityController.onEntityCommand(target.id, "remote.send_cmd",
                                                 {command: "keyboard.text_set " + value});
                console.log("Apple TV keyboard text dispatched to Remote:", target.id);
                sent++;
            } else if (type === "media_player") {
                const companion = matchingCompanionRemote(target);
                if (companion && EntityController.mayCommandEntity(companion.enabled)) {
                    // Recover gracefully if an old KB widget still points at
                    // HA's media player rather than its companion Remote.
                    EntityController.onEntityCommand(companion.id, "remote.send_cmd",
                                                     {command: "keyboard.text_set " + value});
                    console.log("Apple TV keyboard rerouted to companion Remote:", companion.id);
                    sent++;
                } else if (isHomeAssistantMediaPlayer(target)) {
                    hasWrongAppleTvTarget = true;
                } else {
                    // Preserve direct input for integrations supporting it.
                    EntityController.onEntityCommand(target.id, "keyboard.text_set", {text: value});
                    sent++;
                }
            }
        }
        if (hasWrongAppleTvTarget) {
            textEntry.showError(qsTr("Select the Apple TV Remote entity, not its media player, in Keyboard settings."));
            return;
        }
        if (!sent) {
            textEntry.showError(qsTr("No available keyboard target. Choose the Apple TV Remote in Keyboard settings."));
            return;
        }
        // This is dispatch, not guaranteed delivery. Core reports command
        // failures through its existing notifications.
        keyboard.hide();
        textPopup.close();
    }

    onActivityActiveChanged: evaluate()
    onActivityIdChanged: { prompted = ({}); evaluate(); }
    onRulesChanged: evaluate()
    Component.onCompleted: evaluate()

    Connections {
        target: EntityController
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
                trigger: function() { keyboardBridge.submitText(); }
            }
        }
    }
}
