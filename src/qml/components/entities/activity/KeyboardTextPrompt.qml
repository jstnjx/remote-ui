// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.VirtualKeyboard 2.3
import Config 1.0
import Entity.Controller 1.0
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
    property bool submitting: false
    property int submitSerial: 0
    property string pendingManualTarget: ""
    property string currentPrompt: qsTr("Enter text on the media player?")

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

    // Called by a keyboard shortcut Text Button. The manual invocation shares
    // the same native keyboard as sensor automation, but needs no sensor.
    function openManual(mediaId) {
        if (!activityActive || !mediaId) return;
        const media = EntityController.get(mediaId);
        if (!media) {
            pendingManualTarget = mediaId;
            EntityController.load(mediaId);
            return;
        }
        if (media.getTypeAsString() !== "media_player") return;
        pendingManualTarget = "";
        manualMode = true;
        // The optional HA bridge belongs to the current activity and its
        // selected player. Reuse it for manual KB widgets as well as sensor
        // prompts; never send an Apple TV webhook to an unrelated player.
        let webhook = "";
        for (let i = 0; i < rules.length; ++i) {
            const selected = rules[i].mediaPlayerIds || [];
            if (selected.indexOf(mediaId) >= 0 && rules[i].homeAssistantWebhookUrl) {
                webhook = rules[i].homeAssistantWebhookUrl;
                break;
            }
        }
        activeRule = {id: "manual", mediaPlayerIds: [mediaId],
                      homeAssistantWebhookUrl: webhook};
        textPopup.open();
    }

    Timer {
        id: submitTimeout
        interval: 12000
        repeat: false
        onTriggered: {
            if (keyboardBridge.submitting && textPopup.opened) {
                keyboardBridge.submitSerial++;
                keyboardBridge.submitting = false;
                textEntry.showError(qsTr("Home Assistant did not respond."));
            }
        }
    }

    function finishSubmission() {
        submitTimeout.stop();
        submitting = false;
        keyboard.hide();
        textPopup.close();
    }

    function submitViaHomeAssistant(url, value) {
        // A local HA webhook automation calls apple_tv.set_keyboard_text.
        // UC's HA media_player entity does not implement keyboard.text_set
        // and cannot call arbitrary HA actions through entity commands.
        const endpoint = String(url || "").trim();
        if ((endpoint.indexOf("http://") !== 0 && endpoint.indexOf("https://") !== 0) ||
                endpoint.indexOf("/api/webhook/") < 8 ||
                endpoint.indexOf(" ") >= 0 ||
                endpoint.endsWith("/api/webhook/")) {
            textEntry.showError(qsTr("Enter a valid Home Assistant webhook URL in keyboard settings."));
            return;
        }
        submitting = true;
        submitTimeout.restart();
        const serial = ++submitSerial;
        const request = new XMLHttpRequest();
        request.onreadystatechange = function() {
            if (request.readyState !== 4 || serial !== submitSerial ||
                    !keyboardBridge.submitting || !textPopup.opened)
                return;
            submitTimeout.stop();
            if (request.status >= 200 && request.status < 300) {
                keyboardBridge.finishSubmission();
            } else {
                keyboardBridge.submitting = false;
                textEntry.showError(qsTr("Home Assistant rejected the text (HTTP %1).").arg(request.status));
            }
        };
        try {
            request.open("POST", endpoint);
            request.setRequestHeader("Content-Type", "application/json");
            request.onerror = function() {
                if (serial === submitSerial && keyboardBridge.submitting && textPopup.opened) {
                    submitTimeout.stop();
                    keyboardBridge.submitSerial++;
                    keyboardBridge.submitting = false;
                    textEntry.showError(qsTr("Could not reach the Home Assistant webhook."));
                }
            };
            request.send(JSON.stringify({text: value}));
        } catch (e) {
            submitTimeout.stop();
            submitSerial++;
            submitting = false;
            textEntry.showError(qsTr("Could not send text to Home Assistant."));
        }
    }

    function submitText() {
        if (submitting) return;
        if (!activityActive || !activeRule || (!manualMode && !ruleOn(activeRule))) {
            textEntry.showError(qsTr("The activity or sensor is no longer active."));
            return;
        }
        const value = textEntry.inputValue;
        if (value.length === 0) {
            textEntry.showError(qsTr("Enter some text first."));
            return;
        }
        const players = activeRule.mediaPlayerIds || [];
        if (activeRule.homeAssistantWebhookUrl) {
            if (players.length === 0) {
                textEntry.showError(qsTr("Select an Apple TV media player for this rule."));
                return;
            }
            submitViaHomeAssistant(activeRule.homeAssistantWebhookUrl, value);
            return;
        }
        let sent = 0;
        let homeAssistantTarget = false;
        for (let i = 0; i < players.length; ++i) {
            const target = EntityController.get(players[i]);
            if (target && target.getTypeAsString() === "media_player" &&
                    EntityController.mayCommandEntity(target.enabled)) {
                // The bundled HA integration only implements regular media
                // player services. It cannot dispatch apple_tv keyboard actions.
                const integration = String(target.integrationId || "").toLowerCase();
                const id = String(target.id || "").toLowerCase();
                if (integration.indexOf("home-assistant") >= 0 ||
                        integration.indexOf("home_assistant") >= 0 ||
                        integration.indexOf("homeassistant") >= 0 ||
                        integration.indexOf("hass") >= 0 ||
                        id.indexOf("home_assistant") >= 0) {
                    homeAssistantTarget = true;
                    continue;
                }
                EntityController.onEntityCommand(target.id, "keyboard.text_set", {text: value});
                sent++;
            }
        }
        if (homeAssistantTarget) {
            textEntry.showError(qsTr("Home Assistant Apple TV needs a webhook. Configure it in Keyboard input automation."));
            return;
        }
        if (!sent) {
            textEntry.showError(qsTr("No selected media player is available."));
            return;
        }
        finishSubmission();
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

    // Closing the native keyboard must also dismiss its entire input overlay.
    Connections {
        target: keyboard
        function onClosed() {
            if (textPopup.opened && !keyboardBridge.closingKeyboard && !keyboardBridge.submitting) {
                textPopup.close();
            }
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
            submitSerial++;
            submitting = false;
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
            submitTimeout.stop();
            submitSerial++;
            submitting = false;
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
                anchors { top: inputTitle.bottom; topMargin: 25; horizontalCenter: parent.horizontalCenter }
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


        }
    }
}
