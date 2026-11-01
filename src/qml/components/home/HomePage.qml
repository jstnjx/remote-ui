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

    // Follow the real selected tile rather than jumping to the bottom after
    // four items. This keeps D-pad focus visible with arbitrarily many pages.
    function visualForAction(action) {
        if (!action) return null;
        if (action.type === "activity") {
            const index = activityIds.indexOf(action.id);
            return modern ? modernRepeater.itemAt(index) :
                   minimal ? minimalRepeater.itemAt(index) :
                             compactRepeater.itemAt(index);
        }
        if (action.type === "media")
            return mediaFocus ? largeMedia : minimal ? minimalMedia : standardMedia;
        if (action.type === "quick")
            return quickRepeater.itemAt(quickIds.indexOf(action.id));
        if (action.type === "settings")
            return settingsTile;
        return null;
    }

    function ensureSelectedVisible() {
        if (!scroll || !visible) return;
        const target = visualForAction(selectedActions[selectedIndex]);
        if (!target || !target.visible || target.height <= 0) return;
        const top = target.mapToItem(scroll.contentItem, 0, 0).y;
        const bottom = top + target.height;
        const margin = 12;
        const maxY = Math.max(0, scroll.contentHeight - scroll.height);
        if (top < scroll.contentY + margin)
            scroll.contentY = Math.max(0, top - margin);
        else if (bottom > scroll.contentY + scroll.height - margin)
            scroll.contentY = Math.min(maxY, bottom - scroll.height + margin);
    }

    function moveSelection(step) {
        if (!selectedActions.length) return;
        selectedIndex = (selectedIndex + step + selectedActions.length) % selectedActions.length;
        Qt.callLater(ensureSelectedVisible);
    }

    onSelectedIndexChanged: Qt.callLater(ensureSelectedVisible)

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
    MouseArea { anchors.fill: parent }

    Flickable {
        id: scroll
        anchors {
            left: parent.left; right: parent.right
            top: parent.top; bottom: parent.bottom
            topMargin: 48
            bottomMargin: Config.homeShowPageIndicators && home.pageCount > 1 ? 54 : 16
        }
        contentWidth: width
        contentHeight: body.implicitHeight + 28
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: body
            x: 20
            width: Math.max(0, scroll.width - 40)
            spacing: 16

            // The top-bar time is suppressed in the redesigned home.
            Item {
                width: parent.width
                height: home.minimal ? 222 : 124
                visible: Config.homeShowClock
                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 4
                    Text {
                        width: parent.width
                        text: Qt.formatTime(ui.time, Config.clock24h ? "HH:mm" : "hh:mm AP")
                        font: fonts.display(home.minimal ? 90 : 56)
                        color: colors.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: Qt.formatDate(ui.time, "ddd, d MMM")
                        font: fonts.value()
                        color: colors.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }

            // Modern Grid: two columns sized from the available inner width.
            Column {
                width: parent.width
                spacing: 10
                visible: home.modern && Config.homeShowActivities
                Text {
                    text: qsTr("Activities")
                    color: colors.textPrimary
                    font: fonts.heading()
                }
                Grid {
                    id: modernGrid
                    width: parent.width
                    columns: 2
                    spacing: 10
                    Repeater {
                        id: modernRepeater
                        model: home.activityIds
                        delegate: Home.ActivityTile {
                            width: Math.max(0, (modernGrid.width - modernGrid.spacing) / 2)
                            height: 158
                            entityId: modelData
                            selected: home.isSelected("activity", modelData)
                            onTriggered: home.openEntity(id)
                        }
                    }
                }
                Text {
                    visible: home.activityIds.length === 0
                    text: qsTr("No configured activities")
                    color: colors.textSecondary
                    font: fonts.help()
                }
            }

            // Media Focus: enough vertical room for 170px artwork, up to two
            // lines of metadata and a separate 64px transport control band.
            Column {
                width: parent.width
                spacing: 10
                visible: home.mediaFocus && Config.homeShowMedia
                Text {
                    text: qsTr("Now playing")
                    color: colors.textPrimary
                    font: fonts.heading()
                }
                Home.MediaCard {
                    id: largeMedia
                    width: parent.width
                    height: 402
                    large: true
                    player: home.mediaPlayer
                    selected: home.isSelected("media", home.mediaPlayer ? home.mediaPlayer.id : "")
                    openPlayer: function() { home.openMedia(); }
                }
            }

            // Living Room Hub: a bounded summary, no fabricated room details.
            Rectangle {
                width: parent.width
                height: 130
                radius: ui.cornerRadiusSmall
                color: colors.surface
                visible: home.hub
                Column {
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    width: parent.width - 120
                    spacing: 4
                    Text {
                        width: parent.width
                        text: qsTr("Home")
                        font: fonts.title()
                        color: colors.textPrimary
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: qsTr("%1 activities · %2 controls").arg(home.activityIds.length).arg(home.quickIds.length)
                        font: fonts.help()
                        color: colors.textSecondary
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                    }
                }
                Components.Icon {
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    icon: "uc:house"
                    color: colors.textPrimary
                    size: 80
                }
            }

            // Media Focus / Hub: compact 2-column activity list.
            Column {
                width: parent.width
                spacing: 10
                visible: (home.mediaFocus || home.hub) && Config.homeShowActivities
                Text {
                    text: qsTr("Activities")
                    font: fonts.heading()
                    color: colors.textPrimary
                }
                Grid {
                    id: compactGrid
                    width: parent.width
                    columns: 2
                    spacing: 10
                    Repeater {
                        id: compactRepeater
                        model: home.activityIds
                        delegate: Home.ActivityTile {
                            width: Math.max(0, (compactGrid.width - compactGrid.spacing) / 2)
                            height: 98
                            compact: true
                            entityId: modelData
                            selected: home.isSelected("activity", modelData)
                            onTriggered: home.openEntity(id)
                        }
                    }
                }
            }

            // The standard media card fits artwork, title and controls in
            // distinct areas, even with lengthy media metadata.
            Column {
                width: parent.width
                spacing: 10
                visible: (home.modern || home.hub) && Config.homeShowMedia
                Text {
                    text: qsTr("Now playing")
                    font: fonts.heading()
                    color: colors.textPrimary
                }
                Home.MediaCard {
                    id: standardMedia
                    width: parent.width
                    height: 182
                    player: home.mediaPlayer
                    selected: home.isSelected("media", home.mediaPlayer ? home.mediaPlayer.id : "")
                    openPlayer: function() { home.openMedia(); }
                }
            }

            // Minimal uses a four-icon dock rather than compressed text rows.
            Item {
                width: parent.width
                height: 32
                visible: home.minimal
            }
            Column {
                width: parent.width
                spacing: 10
                visible: home.minimal && Config.homeShowActivities
                Row {
                    id: minimalDock
                    width: parent.width
                    spacing: 10
                    Repeater {
                        id: minimalRepeater
                        model: home.activityIds.slice(0, 4)
                        delegate: Home.ActivityTile {
                            width: Math.max(0, (minimalDock.width - 3 * minimalDock.spacing) / 4)
                            height: 96
                            compact: true
                            entityId: modelData
                            selected: home.isSelected("activity", modelData)
                            onTriggered: home.openEntity(id)
                        }
                    }
                }
            }
            Home.MediaCard {
                id: minimalMedia
                width: parent.width
                height: 182
                visible: home.minimal && Config.homeShowMedia
                player: home.mediaPlayer
                selected: home.isSelected("media", home.mediaPlayer ? home.mediaPlayer.id : "")
                openPlayer: function() { home.openMedia(); }
            }

            // Quick controls: four 100px-class icons; do not force labels into
            // narrow columns. Keep the native Settings fallback as a full row.
            Column {
                width: parent.width
                spacing: 10
                visible: Config.homeShowQuickControls
                Text {
                    text: qsTr("Quick controls")
                    visible: !home.minimal
                    font: fonts.heading()
                    color: colors.textPrimary
                }
                Grid {
                    id: quickGrid
                    width: parent.width
                    columns: 4
                    spacing: 10
                    Repeater {
                        id: quickRepeater
                        model: home.quickIds.slice(0, 4)
                        delegate: Home.ActivityTile {
                            width: Math.max(0, (quickGrid.width - 3 * quickGrid.spacing) / 4)
                            height: 96
                            compact: true
                            entityId: modelData
                            selected: home.isSelected("quick", modelData)
                            onTriggered: home.openEntity(id)
                        }
                    }
                }
                Rectangle {
                    id: settingsTile
                    width: parent.width
                    height: 80
                    radius: ui.cornerRadiusSmall
                    color: colors.surface
                    visible: home.quickIds.length === 0 && !ui.profile.restricted
                    Components.Selectable {
                        selected: home.isSelected("settings", "")
                        style: "fill"
                    }
                    Row {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        spacing: 12
                        Components.Icon {
                            icon: "uc:gear"
                            size: 60
                            color: colors.textPrimary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Settings")
                            font: fonts.label()
                            color: colors.textPrimary
                        }
                    }
                    Components.HapticMouseArea {
                        anchors.fill: parent
                        onClicked: home.openSettings()
                    }
                }
            }
        }
    }

    // Page dots remain visible independently of long scrollable home sections.
    Item {
        id: pageFooter
        width: parent.width
        height: 44
        anchors.bottom: parent.bottom
        visible: Config.homeShowPageIndicators && home.pageCount > 1
        Row {
            anchors.centerIn: parent
            spacing: 0
            Repeater {
                model: Math.min(home.pageCount, 8)
                delegate: Item {
                    width: 44
                    height: 44
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: index === 0 ? colors.textPrimary : colors.textSecondary
                        anchors.centerIn: parent
                    }
                    Components.HapticMouseArea {
                        anchors.fill: parent
                        onClicked: home.pageChange(index)
                    }
                }
            }
        }
    }
}
