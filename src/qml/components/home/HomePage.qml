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

// Optional, single-layout redesigned home. The original Page stays loaded
// below this surface, so disabling the setting restores it unchanged.
Item {
    id: home
    width: parent ? parent.width : 480
    height: parent ? parent.height : 850
    clip: true

    readonly property var currentPage: containerMain.item ? containerMain.item.currentPage : null
    readonly property string homeBackgroundImage: currentPage ? currentPage.homeBackgroundImage : ""
    readonly property int rowCount: entityList.count
    property int selectedIndex: 0
    property var mediaPlayer: null

    function isMediaPlayer(id) {
        if (!id || id === "default") return null;
        const entity = EntityController.get(id);
        return entity && entity.type === EntityTypes.Media_player ? entity : null;
    }

    function mediaForActivity(activity) {
        if (!activity) return null;

        const configured = Config.activityArtworkSources;
        let player = isMediaPlayer(configured ? configured[activity.id] : "");
        if (player) return player;

        if (activity.sliderConfig) {
            player = isMediaPlayer(activity.sliderConfig.entityId);
            if (player) return player;
        }

        const pages = activity.ui && activity.ui.pages ? activity.ui.pages : [];
        for (let i = 0; i < pages.length; ++i) {
            const items = pages[i].items || [];
            for (let j = 0; j < items.length; ++j) {
                if (items[j].type !== "media_player") continue;
                player = isMediaPlayer(items[j].media_player_id);
                if (player) return player;
            }
        }

        const included = activity.includedEntities || [];
        for (let k = 0; k < included.length; ++k) {
            player = isMediaPlayer(included[k]);
            if (player) return player;
        }
        return null;
    }

    // The default page already knows which running activities / players are
    // on it, including activities inside configured groups. Do not use the
    // global activity list: it ignores the page's configuration.
    function refreshMedia() {
        let player = null;
        for (let i = 0; i < activePageItems.count; ++i) {
            const delegate = activePageItems.itemAt(i);
            const entity = delegate ? EntityController.get(delegate.entityId) : null;
            if (!entity) continue;

            if (entity.type === EntityTypes.Media_player) {
                player = entity;
                break;
            }
            if (entity.type === EntityTypes.Activity && entity.state === ActivityStates.On) {
                player = mediaForActivity(entity);
                if (player) break;
            }
        }
        mediaPlayer = player;
    }

    function openSettings() {
        if (!ui.profile.restricted)
            loadSecondContainer("qrc:/components/SettingsNew.qml");
    }

    function openMedia() {
        if (!mediaPlayer) return;
        loadSecondContainer(EntityController.screenUrl(mediaPlayer),
                            { "entityId": mediaPlayer.id, "entityObj": mediaPlayer });
    }

    function ensureSelectedVisible() {
        if (!visible || rowCount === 0 || entityList.height <= 0) return;
        entityList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function moveSelection(step) {
        if (rowCount === 0) return;
        selectedIndex = (selectedIndex + step + rowCount) % rowCount;
        Qt.callLater(ensureSelectedVisible);
    }

    function activateSelected(longPress) {
        if (rowCount === 0) return;
        const row = entityList.itemAtIndex(selectedIndex);
        if (!row || !row.item) return;
        if (row.isGroup) {
            if (row.item.state === "closed") {
                if (Config.entityButtonFuncInverted === !!longPress) row.item.toggle();
                else row.item.open();
            } else {
                const currentChild = row.item.groups ? row.item.groups.currentItem : null;
                if (currentChild && currentChild.item) {
                    if (Config.entityButtonFuncInverted === !!longPress)
                        currentChild.item.control();
                    else
                        currentChild.item.open();
                } else if (longPress) {
                    row.item.close();
                }
            }
        } else if (Config.entityButtonFuncInverted !== !!longPress) {
            row.item.open();
        } else {
            row.item.control();
        }
    }

    function scrollToBeginning() {
        if (entityList.count > 0) entityList.positionViewAtBeginning();
    }

    onSelectedIndexChanged: Qt.callLater(ensureSelectedVisible)
    onCurrentPageChanged: {
        selectedIndex = 0;
        Qt.callLater(refreshMedia);
    }
    Component.onCompleted: Qt.callLater(refreshMedia)

    Connections {
        target: EntityController
        ignoreUnknownSignals: true
        function onActivitiesChanged() { home.refreshMedia(); }
        function onEntityLoaded(success, id) {
            if (success) home.refreshMedia();
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: home.visible
        onTriggered: home.refreshMedia()
    }

    // Mirrors the stock first page's running-entities model. Repeater items
    // expose the PageItemList role without requiring a new Core-API endpoint.
    Item {
        visible: false
        Repeater {
            id: activePageItems
            model: home.currentPage ? home.currentPage.homePageActivities : null
            delegate: Item {
                property string entityId: pageItemId
            }
            onItemAdded: Qt.callLater(home.refreshMedia)
            onItemRemoved: Qt.callLater(home.refreshMedia)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: colors.black
    }

    // Status bar: one page title, battery percentage and settings. The clock
    // appears only in the image header, never in this bar.
    Rectangle {
        id: topBar
        z: 1
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 52
        color: colors.black

        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
            spacing: 12
            Components.Icon {
                icon: "uc:house"
                size: 28
                color: colors.offwhite
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: home.currentPage ? home.currentPage.title : qsTr("Home")
                width: Math.min(180, Math.max(90, home.width - 260))
                font: fonts.label()
                color: colors.offwhite
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
            spacing: 9

            Item {
                width: 30
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    id: batteryOutline
                    width: 25; height: 15; radius: 2
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -2
                    color: colors.transparent
                    border { color: colors.offwhite; width: 2 }
                    Rectangle {
                        x: 3; y: 3
                        width: (batteryOutline.width - 6) * Math.max(0, Math.min(100, Battery.level)) / 100
                        height: batteryOutline.height - 6
                        color: Battery.low ? colors.red : colors.offwhite
                    }
                }
                Rectangle {
                    width: 3; height: 7
                    color: colors.offwhite
                    anchors { left: batteryOutline.right; verticalCenter: batteryOutline.verticalCenter }
                }
            }
            Text {
                text: Battery.level + "%"
                font: fonts.help()
                color: colors.offwhite
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 1; height: 28
                color: colors.light
                opacity: 0.4
                anchors.verticalCenter: parent.verticalCenter
            }
            Item {
                width: 42; height: 42
                anchors.verticalCenter: parent.verticalCenter
                Components.Icon {
                    anchors.centerIn: parent
                    icon: "uc:gear"
                    color: colors.offwhite
                    size: 28
                }
                Components.HapticMouseArea {
                    anchors.fill: parent
                    onClicked: home.openSettings()
                }
            }
        }
    }

    Item {
        id: hero
        anchors { top: topBar.bottom; left: parent.left; right: parent.right }
        height: Math.min(220, Math.max(165, home.height * 0.235))
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
            opacity: 0.28
            visible: heroImage.visible
        }

        LinearGradient {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.min(86, hero.height * 0.45)
            visible: heroImage.visible
            start: Qt.point(0, 0)
            end: Qt.point(0, height)
            gradient: Gradient {
                GradientStop { position: 0; color: colors.transparent }
                GradientStop { position: 1; color: colors.black }
            }
        }

        Column {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 22 }
            spacing: 0
            Text {
                text: Qt.formatTime(ui.time, Config.clock24h ? "HH:mm" : "hh:mm AP")
                width: Math.max(0, hero.width - 44)
                font: fonts.display(65)
                color: colors.offwhite
                elide: Text.ElideRight
            }
            Text {
                // Read the time property so the date refreshes at midnight too.
                text: {
                    const tick = ui.time;
                    return Qt.formatDate(new Date(), "ddd, d MMM");
                }
                font: fonts.help()
                color: colors.offwhite
                opacity: 0.8
            }
        }
    }

    Home.MediaCard {
        id: mediaStrip
        visible: home.mediaPlayer !== null
        player: home.mediaPlayer
        openPlayer: function() { home.openMedia(); }
        anchors {
            top: hero.bottom
            left: parent.left
            right: parent.right
            topMargin: visible ? 12 : 0
            leftMargin: 10
            rightMargin: 10
        }
        height: visible ? 100 : 0
    }

    ListView {
        id: entityList
        anchors {
            top: mediaStrip.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            topMargin: home.mediaPlayer ? 12 : 10
            bottomMargin: 8
            leftMargin: 10
            rightMargin: 10
        }
        model: home.currentPage ? home.currentPage.items : null
        currentIndex: home.selectedIndex
        keyNavigationEnabled: false
        maximumFlickVelocity: 6000
        flickDeceleration: 1000
        highlightMoveDuration: 200
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 500

        onCountChanged: {
            if (home.selectedIndex >= count)
                home.selectedIndex = Math.max(0, count - 1);
        }

        delegate: Loader {
            id: rowLoader
            width: entityList.width
            height: item ? item.height : 94
            asynchronous: true
            property bool isCurrentItem: ListView.isCurrentItem
            property bool editMode: false
            property bool isGroup: pageItemType !== 0

            Component.onCompleted: {
                if (pageItemType === 0) {
                    setSource("qrc:/components/entities/Base.qml", {
                        "entityId": pageItemId, "redesignedHomeStyle": true
                    });
                } else {
                    setSource("qrc:/components/group/Base.qml", {
                        "groupId": pageItemId, "redesignedHomeStyle": true
                    });
                }
            }
            onStatusChanged: {
                if (status === Loader.Error)
                    console.warn("Redesigned home row failed:", pageItemId);
            }
        }
    }

    Text {
        anchors.centerIn: entityList
        width: Math.max(0, entityList.width - 24)
        visible: entityList.count === 0
        text: qsTr("Configure entities on this page in the Web Configurator")
        font: fonts.help()
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        color: colors.textSecondary
    }
}
