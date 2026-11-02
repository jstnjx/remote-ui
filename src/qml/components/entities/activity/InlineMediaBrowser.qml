// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import Entity.Controller 1.0
import Entity.MediaPlayer 1.0
import "qrc:/components" as Components
import "qrc:/components/entities/media_player" as MediaPlayerComponents

// Inline media browser for a Text activity widget marked MB;<media_player_id>.
// This is intentionally not a Popup: browsing, coverflow and playback all stay
// inside the configured activity UI grid cell.
Rectangle {
    id: browser
    clip: true
    color: colors.surface
    radius: ui.cornerRadiusSmall

    property string entityId: ""
    property bool browserActive: false
    property var player: null

    readonly property int pageSize: 20
    property var browseItems: []
    property var history: []
    property string folderId: ""
    property string folderType: ""
    property string folderTitle: qsTr("Browse media")
    property int pageNumber: 1
    property int requestedPage: 1
    property int pendingRequestId: -1
    property bool loading: false
    property bool loadingMore: false
    property bool hasMore: false
    property string errorMessage: ""
    property string pendingPlayId: ""

    readonly property bool canBrowse: player && player.enabled &&
                                       player.hasFeature(MediaPlayerFeatures.Browse_media)
    readonly property var currentItem: browseItems.length > 0 && carousel.currentIndex >= 0 &&
                                       carousel.currentIndex < browseItems.length
                                       ? browseItems[carousel.currentIndex] : null
    readonly property real artSize: Math.max(0, Math.min(width * 0.42, height - 108, 212))
    readonly property bool hasArtworkRoom: width >= 160 && height >= 158 && artSize >= 46

    function bindPlayer() {
        if (!entityId) {
            player = null;
            return;
        }
        player = EntityController.get(entityId);
        if (!player) EntityController.load(entityId);
    }

    function reset() {
        pendingRequestId = -1;
        history = [];
        folderId = "";
        folderType = "";
        folderTitle = qsTr("Browse media");
        browseItems = [];
        pageNumber = 1;
        requestedPage = 1;
        loading = false;
        loadingMore = false;
        hasMore = false;
        errorMessage = "";
        pendingPlayId = "";
    }

    function requestPage(page) {
        if (!browserActive || !canBrowse || pendingRequestId >= 0) return;
        requestedPage = page;
        loadingMore = page > 1;
        loading = true;
        errorMessage = "";
        pendingRequestId = player.browseMedia(folderId, folderType, pageSize, page);
        if (pendingRequestId < 0) {
            loading = false;
            loadingMore = false;
            errorMessage = qsTr("Unable to request media");
        }
    }

    function reload() {
        reset();
        if (browserActive && canBrowse) requestPage(1);
    }

    function enterFolder(item) {
        if (!item || !item.can_browse || !item.media_id) return;
        history = history.concat([{
            id: folderId, type: folderType, title: folderTitle,
            items: browseItems.slice(), page: pageNumber,
            more: hasMore, index: carousel.currentIndex
        }]);
        pendingRequestId = -1;
        folderId = item.media_id;
        folderType = item.media_type || "";
        folderTitle = item.title || qsTr("Browse media");
        browseItems = [];
        pageNumber = 1;
        loading = false;
        loadingMore = false;
        hasMore = false;
        errorMessage = "";
        requestPage(1);
    }

    function goBack() {
        if (!history.length) return;
        pendingRequestId = -1; // ignore replies for a folder we already left
        const previous = history[history.length - 1];
        history = history.slice(0, history.length - 1);
        folderId = previous.id;
        folderType = previous.type;
        folderTitle = previous.title;
        browseItems = previous.items;
        pageNumber = previous.page;
        hasMore = previous.more;
        loading = false;
        loadingMore = false;
        errorMessage = "";
        const indexToRestore = previous.index;
        Qt.callLater(function() {
            if (browser.browseItems === previous.items && carousel.count)
                carousel.currentIndex = Math.max(0, Math.min(indexToRestore, carousel.count - 1));
        });
    }

    function loadMore() {
        if (!hasMore || loading || loadingMore || !browserActive) return;
        requestPage(pageNumber + 1);
    }

    function activateItem(item, index) {
        if (!item || !player || !browserActive) return;
        if (index !== carousel.currentIndex) {
            carousel.currentIndex = index;
            return;
        }
        if (item.can_browse) {
            enterFolder(item);
        } else if (item.can_play) {
            pendingPlayId = item.media_id || "";
            // PLAY_NOW is optional; normal play_media works on older integrations.
            if (player.hasFeature(MediaPlayerFeatures.Play_media_action) &&
                    item.play_media_action && item.play_media_action.indexOf("PLAY_NOW") >= 0)
                player.playMedia(item.media_id, item.media_type || "", "PLAY_NOW");
            else
                player.playMedia(item.media_id, item.media_type || "");
        }
    }

    function acceptResult(requestId, media, pagination) {
        if (!browserActive || requestId < 0 || requestId !== pendingRequestId) return;
        pendingRequestId = -1;
        const incoming = media && media.items ? media.items : [];
        const append = loadingMore && requestedPage > 1;
        const selected = append ? carousel.currentIndex : 0;
        browseItems = append ? browseItems.concat(incoming) : incoming.slice();
        pageNumber = requestedPage;
        hasMore = incoming.length > 0 && (pagination && pagination.count > 0
                  ? browseItems.length < pagination.count : incoming.length >= pageSize);
        loading = false;
        loadingMore = false;
        errorMessage = "";
        // Replacing the QML array may reset PathView.currentIndex.
        Qt.callLater(function() {
            if (browser.browserActive && carousel.count)
                carousel.currentIndex = Math.max(0, Math.min(selected, carousel.count - 1));
        });
    }

    function acceptError(requestId, code, message) {
        if (!browserActive || requestId !== pendingRequestId) return;
        pendingRequestId = -1;
        loading = false;
        loadingMore = false;
        if (code === 404) {
            browseItems = [];
            hasMore = false;
        } else {
            errorMessage = message || qsTr("Unable to browse media");
        }
    }

    function imageUrl(item) {
        const url = item && item.thumbnail ? item.thumbnail : "";
        if (!url || url.indexOf("icon://") === 0) return "";
        try { return decodeURIComponent(url); }
        catch (e) { return url; }
    }

    Component.onCompleted: bindPlayer()
    onEntityIdChanged: bindPlayer()
    onPlayerChanged: if (browserActive) reload()
    onBrowserActiveChanged: {
        if (browserActive) reload();
        else pendingRequestId = -1;
    }
    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (success && id === browser.entityId) browser.bindPlayer();
        }
    }
    Connections {
        target: browser.player
        ignoreUnknownSignals: true
        function onBrowseMediaResult(requestId, media, pagination) {
            browser.acceptResult(requestId, media, pagination);
        }
        function onMediaBrowseError(requestId, code, message) {
            browser.acceptError(requestId, code, message);
        }
    }

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Math.min(46, browser.height * 0.27)

        Item {
            id: backButton
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 }
            width: 42
            height: parent.height
            visible: browser.history.length > 0

            Components.Icon {
                anchors.centerIn: parent
                icon: "uc:chevron-left"
                size: 30
                color: colors.offwhite
            }
            Components.HapticMouseArea {
                anchors.fill: parent
                onClicked: browser.goBack()
            }
        }

        Text {
            anchors {
                left: parent.left
                right: refreshButton.left
                verticalCenter: parent.verticalCenter
                leftMargin: backButton.visible ? 48 : 12
                rightMargin: 2
            }
            color: colors.offwhite
            font: fonts.help()
            text: browser.folderTitle
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Item {
            id: refreshButton
            width: 42
            height: parent.height
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
            Components.Icon {
                anchors.centerIn: parent
                icon: "uc:rotate"
                size: 25
                color: colors.offwhite
            }
            Components.HapticMouseArea {
                anchors.fill: parent
                enabled: browser.browserActive && browser.canBrowse
                onClicked: browser.requestPage(1)
            }
        }
    }

    Item {
        id: coverflowRegion
        anchors {
            top: header.bottom
            bottom: metadata.top
            left: parent.left
            right: parent.right
        }
        clip: true

        PathView {
            id: carousel
            anchors.fill: parent
            visible: browser.hasArtworkRoom && browser.browseItems.length > 0
            clip: true
            model: browser.browseItems
            interactive: browser.browserActive && browser.browseItems.length > 1
            pathItemCount: Math.min(5, browser.browseItems.length)
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapOneItem
            // PathView is cyclic by design: no first/last sentinel or dead end.
            onCurrentIndexChanged: {
                if (currentIndex >= browser.browseItems.length - 3) browser.loadMore();
            }

            path: Path {
                startX: -browser.artSize * 0.18
                startY: coverflowRegion.height / 2
                PathAttribute { name: "coverScale"; value: 0.56 }
                PathAttribute { name: "coverAngle"; value: 42 }
                PathAttribute { name: "coverDepth"; value: 1 }
                PathAttribute { name: "coverOpacity"; value: 0.60 }

                PathLine { x: coverflowRegion.width * 0.25; y: coverflowRegion.height / 2 }
                PathAttribute { name: "coverScale"; value: 0.78 }
                PathAttribute { name: "coverAngle"; value: 24 }
                PathAttribute { name: "coverDepth"; value: 10 }
                PathAttribute { name: "coverOpacity"; value: 0.88 }

                PathLine { x: coverflowRegion.width / 2; y: coverflowRegion.height / 2 }
                PathAttribute { name: "coverScale"; value: 1.0 }
                PathAttribute { name: "coverAngle"; value: 0 }
                PathAttribute { name: "coverDepth"; value: 30 }
                PathAttribute { name: "coverOpacity"; value: 1.0 }

                PathLine { x: coverflowRegion.width * 0.75; y: coverflowRegion.height / 2 }
                PathAttribute { name: "coverScale"; value: 0.78 }
                PathAttribute { name: "coverAngle"; value: -24 }
                PathAttribute { name: "coverDepth"; value: 10 }
                PathAttribute { name: "coverOpacity"; value: 0.88 }

                PathLine { x: coverflowRegion.width + browser.artSize * 0.18; y: coverflowRegion.height / 2 }
                PathAttribute { name: "coverScale"; value: 0.56 }
                PathAttribute { name: "coverAngle"; value: -42 }
                PathAttribute { name: "coverDepth"; value: 1 }
                PathAttribute { name: "coverOpacity"; value: 0.60 }
            }

            delegate: Item {
                id: cover
                width: browser.artSize
                height: browser.artSize
                scale: PathView.coverScale
                z: PathView.coverDepth
                opacity: PathView.coverOpacity
                transform: Rotation {
                    origin.x: cover.width / 2
                    origin.y: cover.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: cover.PathView.coverAngle
                }

                Rectangle {
                    anchors.fill: parent
                    color: colors.medium
                    radius: ui.cornerRadiusSmall
                    clip: true
                    MediaPlayerComponents.ImageLoader {
                        id: artwork
                        anchors.fill: parent
                        url: browser.imageUrl(modelData)
                        aspectFit: false
                    }
                    Components.Icon {
                        anchors.centerIn: parent
                        icon: modelData.thumbnail && modelData.thumbnail.indexOf("icon://") === 0
                              ? modelData.thumbnail.slice(7) : "uc:music"
                        size: Math.max(26, cover.width * 0.4)
                        color: colors.offwhite
                        visible: !artwork.url || artwork.failed
                    }
                }
                Components.HapticMouseArea {
                    anchors.fill: parent
                    onClicked: browser.activateItem(modelData, index)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 24)
            visible: !carousel.visible
            text: !browser.hasArtworkRoom ? qsTr("Enlarge media browser widget")
                  : !browser.entityId ? qsTr("Set MB;media_player_entity_id")
                  : !browser.player ? qsTr("Media player unavailable")
                  : !browser.canBrowse ? qsTr("Media browsing unsupported")
                  : browser.errorMessage ? browser.errorMessage
                  : browser.loading ? qsTr("Loading media…") : qsTr("No media found")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            font: fonts.help()
            color: colors.light
        }

        Text {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 10; bottomMargin: 4 }
            visible: carousel.visible && browser.loadingMore
            text: qsTr("Loading…")
            font: fonts.help()
            color: colors.light
        }
    }

    Column {
        id: metadata
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            bottomMargin: 8
            leftMargin: 12
            rightMargin: 12
        }
        height: Math.min(53, browser.height * 0.25)
        spacing: 2
        visible: browser.hasArtworkRoom && browser.currentItem !== null

        Text {
            width: parent.width
            text: browser.currentItem ? browser.currentItem.title || "" : ""
            font: fonts.label()
            color: colors.offwhite
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: browser.currentItem
                  ? browser.currentItem.subtitle || browser.currentItem.artist ||
                    browser.currentItem.album || "" : ""
            font: fonts.help()
            color: colors.light
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }
}
