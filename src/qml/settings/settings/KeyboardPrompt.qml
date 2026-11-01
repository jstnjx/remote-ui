// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import Config 1.0
import Entity.Controller 1.0

import "qrc:/settings" as Settings
import "qrc:/components" as Components

// One activity, its binary On/Off sensor, and a configured media player.
// A blank selection disables prompting; none of the choices sends commands.
Settings.Page {
    id: settingsPage
    scrollTarget: flickable
    initialFocusItem: activityRow

    property var selectionHandler: null

    function selectedName(entityId) {
        if (!entityId) {
            return qsTr("Not selected");
        }
        const entity = EntityController.get(entityId);
        return entity ? entity.name : qsTr("Unavailable");
    }

    function showPicker(kind) {
        pickerModel.clear();
        pickerModel.append({name: qsTr("None (disabled)"), value: ""});

        let ids = [];
        if (kind === "activity") {
            ids = EntityController.getIdsByType("activity");
        } else if (kind === "media_player") {
            ids = EntityController.getIdsByType("media_player");
        } else if (kind === "sensor") {
            const activity = EntityController.get(Config.keyboardActivityId);
            if (activity) {
                const included = activity.includedEntities;
                for (let i = 0; i < included.length; ++i) {
                    const sensor = EntityController.get(included[i]);
                    if (!sensor || sensor.getTypeAsString() !== "sensor") {
                        continue;
                    }
                    // Binary sensors always report the raw "on"/"off" values.
                    // Custom sensors may also directly report On/Off.
                    const raw = String(sensor.rawValue).toLowerCase();
                    if (sensor.getDeviceClass().toLowerCase() === "binary" ||
                            raw === "on" || raw === "off") {
                        ids.push(sensor.id);
                    }
                }
            }
        }

        for (let i = 0; i < ids.length; ++i) {
            const e = EntityController.get(ids[i]);
            if (e) {
                pickerModel.append({name: e.name, value: e.id});
            }
        }

        const chosen = kind === "activity" ? Config.keyboardActivityId
                                           : kind === "sensor" ? Config.keyboardSensorId
                                                               : Config.keyboardMediaPlayerId;
        let currentIndex = 0;
        for (let i = 0; i < pickerModel.count; ++i) {
            if (pickerModel.get(i).value === chosen) {
                currentIndex = i;
                break;
            }
        }

        selectionHandler = function(value) {
            if (kind === "activity") {
                Config.keyboardActivityId = value;
            } else if (kind === "sensor") {
                Config.keyboardSensorId = value;
            } else {
                Config.keyboardMediaPlayerId = value;
            }
        };
        pickerLoader.setSource("qrc:/components/PopupList.qml", {
            title: kind === "activity" ? qsTr("Select activity")
                 : kind === "sensor" ? qsTr("Select On/Off sensor")
                                      : qsTr("Select media player"),
            listModel: pickerModel,
            showSearch: pickerModel.count > 8,
            initialSelected: currentIndex,
            currentValue: chosen
        });
    }

    ListModel {
        id: pickerModel
    }

    Flickable {
        id: flickable
        anchors { left: parent.left; right: parent.right; top: topNavigation.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: rows.height
        clip: true

        ColumnLayout {
            id: rows
            width: parent.width
            spacing: 0

            Components.MenuRow {
                id: activityRow
                text: qsTr("Activity")
                value: settingsPage.selectedName(Config.keyboardActivityId)
                chevron: true
                keypadActivatable: true
                selected: activeFocus && ui.keyNavigationActive
                onClicked: settingsPage.showPicker("activity")
                KeyNavigation.down: sensorRow
            }
            Components.Divider {}

            Components.MenuRow {
                id: sensorRow
                text: qsTr("On/Off sensor")
                value: settingsPage.selectedName(Config.keyboardSensorId)
                enabled: Config.keyboardActivityId !== ""
                chevron: true
                keypadActivatable: true
                selected: activeFocus && ui.keyNavigationActive
                onClicked: settingsPage.showPicker("sensor")
                KeyNavigation.up: activityRow
                KeyNavigation.down: playerRow
            }
            Components.Divider {}

            Components.MenuRow {
                id: playerRow
                text: qsTr("Target media player")
                value: settingsPage.selectedName(Config.keyboardMediaPlayerId)
                chevron: true
                keypadActivatable: true
                selected: activeFocus && ui.keyNavigationActive
                onClicked: settingsPage.showPicker("media_player")
                KeyNavigation.up: sensorRow
            }
            Components.Divider {}

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 22
                width: parent.width - 40
                wrapMode: Text.WordWrap
                font: fonts.help()
                color: colors.textSecondary
                text: qsTr("When the selected sensor reports On while the activity is open, "
                           + "a one-time prompt offers the native keyboard. Text is sent to "
                           + "the selected media player with keyboard.text_set. "
                           + "The prompt can be dismissed until the sensor changes to Off and On again.")
            }
        }
    }

    Loader {
        id: pickerLoader
        anchors.fill: parent

        Connections {
            target: pickerLoader.item
            ignoreUnknownSignals: true
            function onItemSelected(value) {
                if (settingsPage.selectionHandler) {
                    settingsPage.selectionHandler(value);
                }
            }
            function onDone() {
                settingsPage.selectionHandler = null;
                pickerLoader.source = "";
            }
        }
    }
}
