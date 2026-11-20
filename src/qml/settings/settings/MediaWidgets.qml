// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Config 1.0
import Entity.Controller 1.0
import "qrc:/settings" as Settings
import "qrc:/components" as Components

Settings.Page {
    id: settingsPage
    initialFocusItem: shuffleSwitch
    scrollTarget: flickable
    property string selectedActivityId: ""
    property var popupHandler: null
    readonly property var layouts: [qsTr("Standard"), qsTr("Compact"), qsTr("Artwork only"), qsTr("Expanded")]

    function nameFor(entityId) {
        if (!entityId) return qsTr("Activity media player");
        const entity = EntityController.get(entityId);
        return entity ? entity.name : entityId;
    }

    function openPicker(kind) {
        pickerModel.clear();
        if (kind === "activity") {
            const activities = EntityController.getIdsByType("activity");
            for (let i = 0; i < activities.length; ++i) {
                pickerModel.append({name: nameFor(activities[i]), value: activities[i]});
            }
            popupHandler = function(value) { selectedActivityId = value; };
        } else {
            pickerModel.append({name: qsTr("Use activity widget media player"), value: ""});
            const players = EntityController.getIdsByType("media_player");
            for (let i = 0; i < players.length; ++i) {
                pickerModel.append({name: nameFor(players[i]), value: players[i]});
            }
            popupHandler = function(value) {
                const mapping = Object.assign({}, Config.activityArtworkSources);
                if (value) mapping[selectedActivityId] = value;
                else delete mapping[selectedActivityId];
                Config.activityArtworkSources = mapping;
            };
        }
        pickerLoader.setSource("qrc:/components/PopupList.qml", {
            title: kind === "activity" ? qsTr("Select activity") : qsTr("Primary artwork source"),
            listModel: pickerModel,
            showSearch: pickerModel.count > 8
        });
    }

    ListModel { id: pickerModel }

    Flickable {
        id: flickable
        anchors { left: parent.left; right: parent.right; top: topNavigation.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: content.height
        clip: true

        ColumnLayout {
            id: content
            width: parent.width
            spacing: 0

            Components.SettingRow {
                title: qsTr("Shuffle control")
                Components.Switch {
                    id: shuffleSwitch
                    icon: "uc:check"
                    checked: Config.showMediaShuffle
                    trigger: function() { Config.showMediaShuffle = !Config.showMediaShuffle; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.down: repeatSwitch
                }
            }

            Components.SettingRow {
                title: qsTr("Repeat control")
                Components.Switch {
                    id: repeatSwitch
                    icon: "uc:check"
                    checked: Config.showMediaRepeat
                    trigger: function() { Config.showMediaRepeat = !Config.showMediaRepeat; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: shuffleSwitch
                    KeyNavigation.down: browserSwitch
                }
            }

            Components.SettingRow {
                title: qsTr("Media browser control")
                Components.Switch {
                    id: browserSwitch
                    icon: "uc:check"
                    checked: Config.showMediaBrowser
                    trigger: function() { Config.showMediaBrowser = !Config.showMediaBrowser; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: repeatSwitch
                    KeyNavigation.down: sourceSwitch
                }
            }

            Components.SettingRow {
                title: qsTr("Source selection control")
                Components.Switch {
                    id: sourceSwitch
                    icon: "uc:check"
                    checked: Config.showMediaSource
                    trigger: function() { Config.showMediaSource = !Config.showMediaSource; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: browserSwitch
                    KeyNavigation.down: layoutSlider
                }
            }

            Components.SettingRow {
                title: qsTr("Media widget layout")
                value: settingsPage.layouts[Config.mediaWidgetLayout]
                controlBelow: true
                controlBottomSpace: 40
                Components.Slider {
                    id: layoutSlider
                    height: 60
                    from: 0
                    to: 3
                    stepSize: 1
                    value: Config.mediaWidgetLayout
                    lowValueText: qsTr("Standard")
                    highValueText: qsTr("Expanded")
                    onUserInteractionEnded: Config.mediaWidgetLayout = Math.round(value)
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: sourceSwitch
                    KeyNavigation.down: activityRow
                }
            }

            Components.MenuRow {
                id: activityRow
                text: qsTr("Activity")
                value: settingsPage.nameFor(settingsPage.selectedActivityId)
                selected: activeFocus && ui.keyNavigationActive
                keypadActivatable: true
                chevron: true
                onClicked: settingsPage.openPicker("activity")
                KeyNavigation.up: layoutSlider
                KeyNavigation.down: artworkRow
            }
            Components.Divider {}

            Components.MenuRow {
                id: artworkRow
                text: qsTr("Primary artwork & metadata")
                value: selectedActivityId ? nameFor(Config.activityArtworkSources[selectedActivityId] || "") : qsTr("Choose activity")
                selected: activeFocus && ui.keyNavigationActive
                keypadActivatable: true
                chevron: true
                enabled: selectedActivityId !== ""
                onClicked: settingsPage.openPicker("artwork")
                KeyNavigation.up: activityRow
            }
            Components.Divider {}

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 16
                wrapMode: Text.WordWrap
                color: colors.textSecondary
                font: fonts.help()
                text: qsTr("The four controls can be hidden individually. Select an activity and a "
                           + "media player to override its artwork, title, artist and progress "
                           + "metadata. The original media widget still controls its assigned player.")
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
                if (settingsPage.popupHandler) settingsPage.popupHandler(value);
            }
            function onDone() {
                settingsPage.popupHandler = null;
                pickerLoader.source = "";
            }
        }
    }
}
