// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15

import Config 1.0
import Entity.Controller 1.0

import "qrc:/components" as Components

// A sensor-triggered, dismissible offer. The keyboard is never opened without
// user interaction, and the same On state cannot repeatedly reopen the offer.
Item {
    id: keyboardBridge
    width: 0
    height: 0

    property string activityId: ""
    property bool activityActive: false
    property var sensorEntity: null
    property bool promptedThisOn: false

    function sensorIsConfigured() {
        return Config.keyboardActivityId === activityId &&
               Config.keyboardSensorId !== "" &&
               Config.keyboardMediaPlayerId !== "";
    }

    function refreshSensor() {
        if (!sensorIsConfigured()) {
            sensorEntity = null;
            promptedThisOn = false;
            offerPopup.close();
            textPopup.close();
            return;
        }
        const activity = EntityController.get(activityId);
        if (!activity || activity.includedEntities.indexOf(Config.keyboardSensorId) < 0) {
            sensorEntity = null;
            return;
        }

        const sensor = EntityController.get(Config.keyboardSensorId);
        if (!sensor || sensor.getTypeAsString() !== "sensor") {
            sensorEntity = null;
            return;
        }
        if (sensorEntity !== sensor) {
            sensorEntity = sensor;
            promptedThisOn = false;
        }
        evaluateSensor();
    }

    function evaluateSensor() {
        const value = sensorEntity ? String(sensorEntity.rawValue).trim().toLowerCase() : "";
        if (value === "off") {
            promptedThisOn = false;
            offerPopup.close();
            textPopup.close();
            return;
        }
        if (value !== "on" || !activityActive || promptedThisOn || !sensorIsConfigured()) {
            return;
        }
        const target = EntityController.get(Config.keyboardMediaPlayerId);
        if (!target || target.getTypeAsString() !== "media_player") {
            return;
        }

        promptedThisOn = true;
        offerPopup.menuItems = [{
            title: qsTr("Open keyboard"),
            icon: "uc:keyboard",
            callback: function() {
                textPopup.open();
            }
        }];
        offerPopup.open();
    }

    function submitText() {
        if (!sensorIsConfigured() || !activityActive ||
                !sensorEntity || String(sensorEntity.rawValue).toLowerCase() !== "on") {
            textEntry.showError(qsTr("The activity or sensor is no longer active."));
            return;
        }

        const target = EntityController.get(Config.keyboardMediaPlayerId);
        if (!target || target.getTypeAsString() !== "media_player" ||
                !EntityController.mayCommandEntity(target.enabled)) {
            textEntry.showError(qsTr("The media player is unavailable."));
            return;
        }

        const value = textEntry.inputValue;
        if (value.length === 0) {
            textEntry.showError(qsTr("Enter some text first."));
            return;
        }

        // Send text as one command, not one command per keystroke.
        EntityController.onEntityCommand(target.id, "keyboard.text_set", {text: value});
        keyboard.hide();
        textPopup.close();
    }

    Component.onCompleted: refreshSensor()
    onActivityIdChanged: refreshSensor()
    onActivityActiveChanged: {
        if (!activityActive) {
            offerPopup.close();
            textPopup.close();
        } else {
            evaluateSensor();
        }
    }

    Connections {
        target: Config
        function onKeyboardActivityIdChanged() { keyboardBridge.refreshSensor(); }
        function onKeyboardSensorIdChanged() { keyboardBridge.refreshSensor(); }
        function onKeyboardMediaPlayerIdChanged() { keyboardBridge.refreshSensor(); }
    }

    Connections {
        target: EntityController
        function onEntityLoaded(success, entityId) {
            if (success && (entityId === Config.keyboardSensorId ||
                            entityId === Config.keyboardMediaPlayerId ||
                            entityId === keyboardBridge.activityId)) {
                keyboardBridge.refreshSensor();
            }
        }
    }

    Connections {
        target: sensorEntity
        ignoreUnknownSignals: true
        function onValueChanged() { keyboardBridge.evaluateSensor(); }
        function onStateChanged() { keyboardBridge.evaluateSensor(); }
    }

    // Reuse the remote's existing menu popup for the one-time question.
    Components.PopupMenu {
        id: offerPopup
        parent: Overlay.overlay
        title: qsTr("Enter text on the media player?")
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
