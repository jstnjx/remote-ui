// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import Config 1.0
import Entity.Controller 1.0
import Entity.Activity 1.0
import Entity.MediaPlayer 1.0
import "qrc:/components" as Components
import "qrc:/components/home" as Home

// Optional first-page surface. It never replaces Page.qml or its page model.
// The original view stays alive underneath and is revealed if loading fails.
Item {
    id: home
    width: parent ? parent.width : 480
    height: parent ? parent.height : 850
    clip: true

    property var activityIds: []
    property var quickIds: []
    property var mediaPlayer: null
    property int selectedIndex: 0
    property int pageCount: ui.pages.count
    readonly property bool modern: Config.homeScreenLayout === 0
    readonly property bool mediaFocus: Config.homeScreenLayout === 1
    readonly property bool hub: Config.homeScreenLayout === 2
    readonly property bool minimal: Config.homeScreenLayout === 3
    readonly property var selectedActions: {
        const result = [];
        if (Config.homeShowMedia && mediaPlayer && mediaFocus)
            result.push({type:"media", id: mediaPlayer.id});
        if (Config.homeShowActivities) {
            const activityLimit = minimal ? Math.min(activityIds.length, 4) : activityIds.length;
            for (let i = 0; i < activityLimit; ++i)
                result.push({type:"activity", id: activityIds[i]});
        }
        if (Config.homeShowMedia && mediaPlayer && !mediaFocus)
            result.push({type:"media", id: mediaPlayer.id});
        if (Config.homeShowQuickControls) {
            for (let i = 0; i < Math.min(quickIds.length, 4); ++i)
                result.push({type:"quick", id: quickIds[i]});
            if (!quickIds.length) result.push({type:"settings", id:""});
        }
        return result;
    }

    function refresh() {
        const ids = EntityController.getIdsByType("activity");
        activityIds = ids.slice();
        const available = EntityController.getIdsByType("light")
                          .concat(EntityController.getIdsByType("switch"));
        quickIds = available.slice(0, 4);
        const players = EntityController.getIdsByType("media_player");
        let chosen = null;
        for (let i = 0; i < players.length; ++i) {
            const p = EntityController.get(players[i]);
            if (!p) continue;
            if (!chosen) chosen = p;
            if (p.state === MediaPlayerStates.Playing) { chosen = p; break; }
            if (p.state === MediaPlayerStates.Paused && chosen.state !== MediaPlayerStates.Playing) chosen = p;
        }
        mediaPlayer = chosen;
        if (selectedIndex >= selectedActions.length) selectedIndex = Math.max(0, selectedActions.length - 1);
    }

    function isSelected(type, id) {
        const action = selectedActions[selectedIndex];
        return action && action.type === type && action.id === id;
    }

    function openEntity(id) {
        const entity = EntityController.get(id);
        if (!entity) { EntityController.load(id); return; }
        const url = EntityController.screenUrl(entity);
        if (url.toString() !== "") {
            loadSecondContainer(url, {entityId: entity.id, entityObj: entity});
        }
    }

    function openMedia() {
        if (mediaPlayer) openEntity(mediaPlayer.id);
    }

    function openSettings() {
        if (!ui.profile.restricted) loadSecondContainer("qrc:/components/SettingsNew.qml");
    }

    function moveSelection(step) {
        if (!selectedActions.length) return;
        selectedIndex = (selectedIndex + step + selectedActions.length) % selectedActions.length;
        // Keep the selected rows visible during D-pad navigation.
        if (selectedIndex > 3 && !minimal)
            scroll.contentY = Math.max(0, scroll.contentHeight - scroll.height);
        else
            scroll.contentY = 0;
    }

    function activateSelected() {
        if (!selectedActions.length) return;
        const action = selectedActions[selectedIndex];
        if (action.type === "media") openMedia();
        else if (action.type === "settings") openSettings();
        else openEntity(action.id);
    }

    function pageChange(index) {
        if (containerMain.item && containerMain.item.pages)
            containerMain.item.pages.currentIndex = index;
    }

    Component.onCompleted: refresh()
    Connections {
        target: EntityController
        function onActivitiesChanged() { home.refresh(); }
        function onEntityLoaded(success, entityId) { if (success) home.refresh(); }
    }
    Timer {
        interval: 4000
        running: home.visible
        repeat: true
        onTriggered: home.refresh()
    }

    Rectangle { anchors.fill: parent; color: colors.bg }
    // Absorb taps on unused space; never pass them to the legacy page below.
    MouseArea { anchors.fill: parent }

    Flickable {
        id: scroll
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
        anchors.topMargin: 48
        anchors.bottomMargin: 36
        contentWidth: width
        contentHeight: content.implicitHeight + 28
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            x: 20
            width: parent.width - 40
            spacing: 20

            // Stock page language: one prominent display treatment, centered
            // on black. The status bar clock is hidden while this is active.
            Item {
                width: parent.width
                height: home.minimal ? 310 : 150
                visible: Config.homeShowClock

                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 4

                    Text {
                        width: parent.width
                        text: Qt.formatTime(ui.time, Config.clock24h ? "HH:mm" : "hh:mm AP")
                        color: colors.textPrimary
                        font: fonts.display(home.minimal ? 90 : 56)
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        width: parent.width
                        text: Qt.formatDate(ui.time, "ddd, d MMM")
                        color: colors.textSecondary
                        font: fonts.value()
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Layout 0: Modern Grid — the balanced default.
            Column {
                width: parent.width
                spacing: 12
                visible: home.modern
                Text {
                    text: qsTr("Activities")
                    visible: Config.homeShowActivities
                    color: colors.textPrimary
                    font: fonts.heading()
                }
                Grid {
                    id: modernGrid
                    width: parent.width
                    columns: 2
                    spacing: 12
                    visible: Config.homeShowActivities
                    Repeater {
                        model: home.activityIds
                        delegate: Home.ActivityTile {
                            width: (modernGrid.width - modernGrid.spacing) / 2
                            height: 178
                            entityId: modelData
                            selected: home.isSelected("activity", modelData)
                            onTriggered: home.openEntity(id)
                        }
                    }
                }
                Text {
                    visible: Config.homeShowActivities && home.activityIds.length === 0
                    text: qsTr("No configured activities")
                    color: colors.textSecondary
                    font: fonts.help()
                }
            }

            // Layout 1: Media Focus — artwork and transport first.
            Column {
                width: parent.width
                spacing: 12
                visible: home.mediaFocus && Config.homeShowMedia
                Text { text: qsTr("Now playing"); color: colors.textPrimary; font: fonts.heading() }
                Home.MediaCard {
                    width: parent.width
                    height: 405
                    large: true
                    selected: home.isSelected("media", home.mediaPlayer ? home.mediaPlayer.id : "")
                    player: home.mediaPlayer
                    openPlayer: function() { home.openMedia(); }
                }
            }

            // Layout 2: room-style hub. Its quick controls use configured entities.
            Column {
                width: parent.width
                spacing: 12
                visible: home.hub
                Rectangle {
                    width: parent.width
                    height: 150
                    radius: ui.cornerRadiusSmall
                    color: colors.surface

                    Column {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: qsTr("Home"); color: colors.textPrimary; font: fonts.title() }
                        Text {
                            text: qsTr("%1 activities · %2 controls").arg(home.activityIds.length).arg(home.quickIds.length)
                            color: colors.textSecondary
                            font: fonts.help()
                        }
                    }
                    Components.Icon {
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        icon: "uc:house"
                        color: colors.textPrimary
                        size: 80
                    }
                }
            }

            // Alternative compact activities list for Media Focus / Living Room Hub.
            Column {
                width: parent.width
                spacing: 12
                visible: (home.mediaFocus || home.hub) && Config.homeShowActivities
                Text { text: qsTr("Activities"); color: colors.textPrimary; font: fonts.heading() }
                Grid {
                    id: compactGrid
                    width: parent.width
                    columns: 2
                    spacing: 12
                    Repeater {
                        model: home.activityIds
                        delegate: Home.ActivityTile {
                            width: (compactGrid.width - compactGrid.spacing) / 2
                            height: 130
                            compact: true
                            entityId: modelData
                            selected: home.isSelected("activity", modelData)
                            onTriggered: home.openEntity(id)
                        }
                    }
                }
            }

            // Modern Grid / Hub now-playing card.
            Column {
                width: parent.width
                spacing: 12
                visible: !home.mediaFocus && !home.minimal && Config.homeShowMedia
                Text { text: qsTr("Now playing"); color: colors.textPrimary; font: fonts.heading() }
                Home.MediaCard {
                    width: parent.width
                    height: 180
                    selected: home.isSelected("media", home.mediaPlayer ? home.mediaPlayer.id : "")
                    player: home.mediaPlayer
                    openPlayer: function() { home.openMedia(); }
                }
            }

            // Minimal: a deliberately empty canvas above the activity dock.
            Item { width: parent.width; height: 70; visible: home.minimal }

            // Minimal always shows an activity dock if enabled.
            Column {
                width: parent.width
                spacing: 12
                visible: home.minimal && Config.homeShowActivities
                Row {
                    id: minimalDock
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: home.activityIds.slice(0, 4)
                        delegate: Home.ActivityTile {
                            width: (minimalDock.width - 3 * minimalDock.spacing) / 4
                            height: 130
                            compact: true
                            entityId: modelData
                            selected: home.isSelected("activity", modelData)
                            onTriggered: home.openEntity(id)
                        }
                    }
                }
            }

            // Optional media on the otherwise minimal home layout.
            Home.MediaCard {
                width: parent.width
                height: 180
                visible: home.minimal && Config.homeShowMedia
                player: home.mediaPlayer
                openPlayer: function() { home.openMedia(); }
            }

            // Shared native quick-access tiles, populated with configured entities.
            Column {
                width: parent.width
                spacing: 12
                visible: Config.homeShowQuickControls
                Text { text: qsTr("Quick controls"); color: colors.textPrimary; font: fonts.heading(); visible: !home.minimal }
                Row {
                    id: quickRow
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: home.quickIds.slice(0, 4)
                        delegate: Home.ActivityTile {
                            width: (quickRow.width - 3 * quickRow.spacing) / 4
                            height: 130
                            compact: true
                            entityId: modelData
                            selected: home.isSelected("quick", modelData)
                            onTriggered: home.openEntity(id)
                        }
                    }
                    Rectangle {
                        visible: home.quickIds.length === 0 && !ui.profile.restricted
                        width: 190; height: 80
                        radius: ui.cornerRadiusSmall
                        color: colors.surface
                        Components.Selectable {
                            selected: home.isSelected("settings", "")
                            style: "fill"
                        }
                        Components.Icon {
                            icon: "uc:gear"; size: 45; color: colors.textPrimary
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        }
                        Text {
                            text: qsTr("Settings")
                            color: colors.textPrimary
                            font: fonts.label()
                            anchors { left: parent.left; leftMargin: 65; verticalCenter: parent.verticalCenter }
                        }
                        Components.HapticMouseArea { anchors.fill: parent; onClicked: home.openSettings() }
                    }
                }
            }

            // Real page indicators, tied to the existing page model.
            Row {
                width: parent.width
                height: 26
                spacing: 14
                visible: Config.homeShowPageIndicators && home.pageCount > 1
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: Math.min(home.pageCount, 8)
                    delegate: Rectangle {
                        width: 10; height: 10; radius: 5
                        color: index === 0 ? colors.textPrimary : colors.textSecondary
                        Components.HapticMouseArea {
                            anchors.fill: parent
                            onClicked: home.pageChange(index)
                        }
                    }
                }
            }
        }
    }
}
