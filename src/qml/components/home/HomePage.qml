// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.0
import Config 1.0
import Battery 1.0
import Entity.Controller 1.0
import Entity.Activity 1.0
import "qrc:/components" as Components
import "qrc:/components/home" as Home

// A single optional home layout. The original first page stays loaded underneath.
Item {
    id: home
    width: parent ? parent.width : 480
    height: parent ? parent.height : 850
    clip: true

    property var activityIds: []
    property var activeActivity: null
    property var mediaPlayer: null
    property int selectedIndex: 0
    readonly property var selectedActions: activityIds.map(function(id) {
        return { type: "activity", id: id };
    })
    readonly property string homeBackgroundImage: containerMain.item && containerMain.item.currentPage
                                                  ? containerMain.item.currentPage.homeBackgroundImage : ""

    function isMediaPlayer(id) {
        if (!id || id === "default") return null;
        const entity = EntityController.get(id);
        return entity && entity.type === EntityTypes.Media_player ? entity : null;
    }

    function mediaForActivity(activity) {
        if (!activity) return null;

        // Prefer the explicitly selected artwork/media source for this activity.
        const configured = Config.activityArtworkSources;
        let player = isMediaPlayer(configured ? configured[activity.id] : "");
        if (player) return player;

        // The activity's linked media-player/slider entity is next.
        if (activity.sliderConfig) {
            player = isMediaPlayer(activity.sliderConfig.entityId);
            if (player) return player;
        }

        // Match the media-player widgets used by the activity UI itself.
        const activityPages = activity.ui && activity.ui.pages ? activity.ui.pages : [];
        for (let i = 0; i < activityPages.length; ++i) {
            const items = activityPages[i].items || [];
            for (let j = 0; j < items.length; ++j) {
                if (items[j].type !== "media_player") continue;
                player = isMediaPlayer(items[j].media_player_id);
                if (player) return player;
            }
        }

        // Finally, a media player explicitly included in this activity.
        const included = activity.includedEntities || [];
        for (let k = 0; k < included.length; ++k) {
            player = isMediaPlayer(included[k]);
            if (player) return player;
        }
        return null;
    }

    function refresh() {
        const ids = EntityController.getIdsByType("activity");
        if (JSON.stringify(activityIds) !== JSON.stringify(ids))
            activityIds = ids.slice();

        let active = null;
        for (let i = 0; i < ids.length; ++i) {
            const entity = EntityController.get(ids[i]);
            if (entity && entity.state === ActivityStates.On) {
                active = entity;
                break;
            }
        }
        activeActivity = active;
        mediaPlayer = mediaForActivity(active);
        if (selectedIndex >= activityIds.length)
            selectedIndex = Math.max(0, activityIds.length - 1);
    }

    function openEntity(id) {
        const entity = EntityController.get(id);
        if (!entity) {
            EntityController.load(id);
            return;
        }
        const url = EntityController.screenUrl(entity);
        if (url.toString() !== "")
            loadSecondContainer(url, {entityId: entity.id, entityObj: entity});
    }

    function openMedia() {
        if (mediaPlayer) openEntity(mediaPlayer.id);
    }

    function openSettings() {
        if (!ui.profile.restricted)
            loadSecondContainer("qrc:/components/SettingsNew.qml");
    }

    function ensureSelectedVisible() {
        if (!visible || gridViewport.height <= 0) return;
        const item = activityRepeater.itemAt(selectedIndex);
        if (!item) return;
        const top = item.mapToItem(gridContents, 0, 0).y;
        const bottom = top + item.height;
        if (top < gridViewport.contentY)
            gridViewport.contentY = Math.max(0, top - 6);
        else if (bottom > gridViewport.contentY + gridViewport.height)
            gridViewport.contentY = Math.min(gridViewport.contentHeight - gridViewport.height,
                                            bottom - gridViewport.height + 6);
    }

    function moveSelection(step) {
        if (!activityIds.length) return;
        selectedIndex = (selectedIndex + step + activityIds.length) % activityIds.length;
        Qt.callLater(ensureSelectedVisible);
    }

    function activateSelected() {
        if (activityIds.length)
            openEntity(activityIds[selectedIndex]);
    }

    onSelectedIndexChanged: Qt.callLater(ensureSelectedVisible)
    Component.onCompleted: refresh()

    Connections {
        target: EntityController
        function onActivitiesChanged() { home.refresh(); }
        function onEntityLoaded(success, entityId) {
            if (success) home.refresh();
        }
    }

    // State changes are delivered on entity objects; periodically reselect only
    // the active source, without rebuilding an unchanged activities model.
    Timer {
        interval: 2000
        running: home.visible
        repeat: true
        onTriggered: home.refresh()
    }

    Rectangle {
        anchors.fill: parent
        color: colors.bg
    }
    MouseArea { anchors.fill: parent }

    Item {
        id: hero
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Math.min(320, Math.max(220, home.height * 0.39))
        clip: true

        Image {
            id: heroImage
            anchors.fill: parent
            source: home.homeBackgroundImage ? resource.getBackgroundImage(home.homeBackgroundImage) : ""
            visible: home.homeBackgroundImage !== ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: width
            sourceSize.height: height
        }

        Rectangle {
            anchors.fill: parent
            color: colors.black
            opacity: 0.4
            visible: heroImage.visible
        }

        LinearGradient {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.min(140, hero.height * 0.5)
            visible: heroImage.visible
            start: Qt.point(0, 0)
            end: Qt.point(0, height)
            gradient: Gradient {
                GradientStop { position: 0; color: colors.transparent }
                GradientStop { position: 1; color: colors.bg }
            }
        }

        Row {
            id: rightHeader
            anchors { top: parent.top; right: parent.right; topMargin: 26; rightMargin: 20 }
            height: 46
            spacing: 8

            Item {
                width: 31
                height: 30
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: batteryOutline
                    width: 26; height: 16; radius: 3
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -2
                    color: colors.transparent
                    border { color: colors.offwhite; width: 2 }

                    Rectangle {
                        x: 3; y: 3
                        width: (batteryOutline.width - 6) * Math.max(0, Math.min(100, Battery.level)) / 100
                        height: batteryOutline.height - 6
                        radius: 1
                        color: Battery.low ? colors.red : colors.offwhite
                    }
                }
                Rectangle {
                    width: 3; height: 7; radius: 1
                    anchors { left: batteryOutline.right; verticalCenter: batteryOutline.verticalCenter }
                    color: colors.offwhite
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.level + "%"
                font: fonts.help()
                color: colors.offwhite
            }

            Item {
                width: 46; height: 46

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: colors.surface
                    opacity: 0.85
                }
                Components.Icon {
                    anchors.centerIn: parent
                    icon: "uc:gear"
                    size: 26
                    color: colors.offwhite
                }
                Components.HapticMouseArea {
                    anchors.fill: parent
                    onClicked: home.openSettings()
                }
            }
        }

        Column {
            anchors {
                left: parent.left
                right: rightHeader.left
                top: parent.top
                leftMargin: 20
                rightMargin: 8
                topMargin: 29
            }
            spacing: 0

            Text {
                width: parent.width
                height: 76
                text: Qt.formatTime(ui.time, Config.clock24h ? "HH:mm" : "hh:mm AP")
                font: fonts.display(62)
                fontSizeMode: Text.Fit
                minimumPixelSize: 32
                verticalAlignment: Text.AlignVCenter
                color: colors.offwhite
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: Qt.formatDate(ui.time, "ddd, d MMM")
                font: fonts.value()
                color: colors.offwhite
                opacity: 0.85
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }
    }

    Flickable {
        id: gridViewport
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: 20; rightMargin: 20; bottomMargin: 24 }
        height: Math.min(gridContents.implicitHeight,
                         Math.max(0, home.height - hero.height - 24 -
                                  (home.mediaPlayer ? 116 : 24)))
        contentWidth: width
        contentHeight: gridContents.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Grid {
            id: gridContents
            width: gridViewport.width
            columns: 2
            spacing: 12

            Repeater {
                id: activityRepeater
                model: home.activityIds

                delegate: Home.ActivityTile {
                    width: Math.max(0, (gridContents.width - gridContents.spacing) / 2)
                    height: 104
                    entityId: modelData
                    showLabel: Config.homeShowActivityLabels
                    selected: index === home.selectedIndex && ui.keyNavigationActive
                    onTriggered: home.openEntity(id)
                }
            }
        }
    }

    Home.MediaCard {
        id: mediaStrip
        visible: home.mediaPlayer !== null
        player: home.mediaPlayer
        openPlayer: function() { home.openMedia(); }
        anchors {
            left: gridViewport.left
            right: gridViewport.right
            bottom: gridViewport.top
            bottomMargin: 16
        }
        height: 84
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 36 }
        visible: home.activityIds.length === 0
        text: qsTr("No configured activities")
        font: fonts.help()
        color: colors.textSecondary
    }
}
