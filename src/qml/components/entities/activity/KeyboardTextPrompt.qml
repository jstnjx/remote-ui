// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
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

    function submitText() {
        if (!activityActive || !activeRule || !ruleOn(activeRule)) {
            textEntry.showError(qsTr("The activity or sensor is no longer active."));
            return;
        }
        const value = textEntry.inputValue;
        if (value.length === 0) {
            textEntry.showError(qsTr("Enter some text first."));
            return;
        }
        const players = activeRule.mediaPlayerIds || [];
        let sent = 0;
        for (let i = 0; i < players.length; ++i) {
            const target = EntityController.get(players[i]);
            if (target && target.getTypeAsString() === "media_player" &&
                    EntityController.mayCommandEntity(target.enabled)) {
                EntityController.onEntityCommand(target.id, "keyboard.text_set", {text: value});
                sent++;
            }
        }
        if (!sent) {
            textEntry.showError(qsTr("No selected media player is available."));
            return;
        }
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
            if (success && keyboardBridge.watchedSensorIds.indexOf(entityId) >= 0) keyboardBridge.evaluate();
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

            Text {
                id: hint
                width: parent.width - 40
                anchors { top: inputTitle.bottom; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                text: qsTr("Type text to send to the configured media player.")
                color: colors.textSecondary
                font: fonts.prose()
                wrapMode: Text.WordWrap
            }

            Components.InputField {
                id: textEntry
                width: parent.width - 40
                anchors { top: hint.bottom; topMargin: 15; horizontalCenter: parent.horizontalCenter }
                moveInput: false
                keyboardFollowsFocus: true
                label: qsTr("Text")
                inputField.placeholderText: qsTr("Enter text")

                Connections {
                    target: textEntry.inputField
                    function onAccepted() { keyboardBridge.submitText(); }
                }
            }

            Row {
                width: parent.width - 40
                spacing: 12
                anchors { top: textEntry.bottom; topMargin: 15; horizontalCenter: parent.horizontalCenter }

                Components.Button {
                    width: (parent.width - parent.spacing) / 2
                    variant: "secondary"
                    text: qsTr("Cancel")
                    trigger: function() { textPopup.close(); }
                    KeyNavigation.right: sendButton
                }

                Components.Button {
                    id: sendButton
                    width: (parent.width - parent.spacing) / 2
                    text: qsTr("Send")
                    trigger: function() { keyboardBridge.submitText(); }
                }
            }
        }
    }
}
