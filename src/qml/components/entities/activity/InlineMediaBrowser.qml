// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import Entity.Controller 1.0
import Entity.MediaPlayer 1.0
import Config 1.0
import "qrc:/components" as Components
import "qrc:/components/entities/media_player" as MediaPlayerComponents

// Inline media browser for a Text activity widget marked MB;<media_player_id>.
// This is intentionally not a Popup: browsing, coverflow and playback all stay
// inside the configured activity UI grid cell.
Rectangle {
    id: browser
    clip: true
    // Let the covers lead visually: one uninterrupted black canvas.
    color: colors.black
    radius: 0

    // The visible Text widget only needs "MB" or a short selector such as
    // "MB;ps5". Keep the resolved full ID separate from the authored text.
    property string entitySelector: ""
    property string commandEntityId: ""
    property var activityEntity: null
    property string entityId: ""
    property string selectionMessage: ""
    property bool browserActive: false
    property var player: null

    readonly property int pageSize: 20
    property var browseItems: []
    // The Core browse response is a container with child items. Retain it
    // just like the full MediaBrowser: playlists/albums can be playable even
    // when their server returns no child tracks.
    property var currentContainer: null
    property var history: []
    property int navigationRevision: 0
    property string folderId: ""
    property string folderType: ""
    property int pageNumber: 1
    property int requestedPage: 1
    property int pendingRequestId: -1
    property bool loading: false
    property bool loadingMore: false
    property bool hasMore: false
    property string errorMessage: ""
    property bool restoringModel: false

    readonly property bool canBrowse: player && player.type === EntityTypes.Media_player &&
                                       player.enabled && player.hasFeature(MediaPlayerFeatures.Browse_media)
    // If a playable album/playlist has no browseable children, expose its
    // container as a playable cover rather than incorrectly saying "No media
    // found". The synthetic flag prevents browsing recursively into itself.
    readonly property var displayItems: browseItems.length > 0 ? browseItems :
        (currentContainer && currentContainer.can_play &&
         (currentContainer.media_class === "playlist" ||
          currentContainer.media_class === "album") ?
         [Object.assign({}, currentContainer, {
             __containerPlay: true, can_browse: false
         })] : [])
    readonly property var currentItem: displayItems.length > 0 && carousel.currentIndex >= 0 &&
                                       carousel.currentIndex < displayItems.length
                                       ? displayItems[carousel.currentIndex] : null
    // Enlarge the center cover, while reserving the small bottom metadata strip.
    // The view clips at its widget bounds even on narrow activity grid layouts.
    readonly property real artSize: Math.max(0, Math.min(width * 0.68, height - 86, 340))
    readonly property bool hasArtworkRoom: width >= 160 && height >= 158 && artSize >= 64

    function activityPlayerIds() {
        const ids = [];
        if (commandEntityId) ids.push(commandEntityId);
        if (!activityEntity) return ids;

        // Explicit activity artwork/media source has the highest priority.
        const configured = Config.activityArtworkSources;
        if (configured && configured[activityEntity.id])
            ids.push(configured[activityEntity.id]);

        const slider = activityEntity.sliderConfig;
        if (slider && slider.entityId && slider.entityId !== "default")
            ids.push(slider.entityId);

        // Native activity media-player widgets already reference the right ID,
        // even if a media entity has not finished loading yet.
        const pages = activityEntity.ui && activityEntity.ui.pages ? activityEntity.ui.pages : [];
        for (let i = 0; i < pages.length; ++i) {
            const items = pages[i].items || [];
            for (let j = 0; j < items.length; ++j) {
                if (items[j].type === "media_player" && items[j].media_player_id)
                    ids.push(items[j].media_player_id);
            }
        }

        const included = activityEntity.includedEntities || [];
        for (let k = 0; k < included.length; ++k) ids.push(included[k]);
        return ids;
    }

    function resolveTarget() {
        const configured = EntityController.getIdsByType("media_player") || [];
        const selector = entitySelector.trim();
        let resolved = "";
        let message = "";

        if (selector) {
            // An exact ID still works for API-created widgets with longer text.
            if (configured.indexOf(selector) >= 0) {
                resolved = selector;
            } else {
                const needle = selector.toLowerCase();
                const matches = configured.filter(function(id) {
                    const full = id.toLowerCase();
                    const last = full.substring(full.lastIndexOf(".") + 1);
                    return last === needle ||
                           last.indexOf(needle) === 0 ||
                           full.substring(full.length - needle.length) === needle;
                });
                if (matches.length === 1)
                    resolved = matches[0];
                else if (matches.length > 1)
                    message = qsTr("Several media players match. Use a longer MB suffix.");
                else if (selector.indexOf(".") >= 0)
                    resolved = selector; // Backward compatibility for full IDs.
                else
                    message = qsTr("No media player matches MB;%1").arg(selector);
            }
        } else {
            const preferred = activityPlayerIds();
            for (let i = 0; i < preferred.length; ++i) {
                if (configured.indexOf(preferred[i]) >= 0) {
                    resolved = preferred[i];
                    break;
                }
            }
            if (!resolved && configured.length === 1)
                resolved = configured[0];
            if (!resolved)
                message = qsTr("Use MB;short_id or link a media player to this activity");
        }

        selectionMessage = message;
        if (entityId !== resolved) entityId = resolved;
        else if (resolved && !player) bindPlayer();
    }

    function bindPlayer() {
        if (!entityId) {
            player = null;
            return;
        }
        const entity = EntityController.get(entityId);
        player = entity && entity.type === EntityTypes.Media_player ? entity : null;
        if (!entity) EntityController.load(entityId);
    }

    function reset() {
        navigationRevision++;
        pendingRequestId = -1;
        history = [];
        currentContainer = null;
        folderId = "";
        folderType = "";
        browseItems = [];
        pageNumber = 1;
        requestedPage = 1;
        loading = false;
        loadingMore = false;
        hasMore = false;
        errorMessage = "";
    }

    function requestPage(page) {
        if (!browserActive || !canBrowse || pendingRequestId >= 0) return;
        requestedPage = page;
        loadingMore = page > 1;
        loading = true;
        errorMessage = "";
        // Match the full MediaBrowser's exact browseMedia request contract.
        // No flattened or reconstructed paths: the integration owns media_id.
        const requestedId = folderId;
        const requestedType = folderType;
        pendingRequestId = player.browseMedia(requestedId, requestedType, pageSize, page);
        console.log("Inline MB browse request:", pendingRequestId,
                    "depth:", history.length, "media_id:", requestedId,
                    "media_type:", requestedType, "page:", page);
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
        if (!item || item.__containerPlay) return;
        const nestedItems = item.items && item.items.length ? item.items : [];
        if (!item.can_browse && !nestedItems.length) return;
        if (!item.media_id && !nestedItems.length) return;
        const savedIndex = carousel.currentIndex;
        navigationRevision++;
        history = history.concat([{
            id: folderId, type: folderType, container: currentContainer,
            items: browseItems.slice(), page: pageNumber,
            more: hasMore, index: savedIndex
        }]);
        pendingRequestId = -1;
        folderId = item.media_id || "";
        folderType = item.media_type || "";
        currentContainer = item;
        // Some integrations embed children rather than expose a browseable
        // media_id. Use those children directly instead of showing emptiness.
        browseItems = nestedItems.slice();
        pageNumber = 1;
        requestedPage = 1;
        loading = false;
        loadingMore = false;
        hasMore = false;
        errorMessage = "";
        if (item.media_id && item.can_browse)
            requestPage(1);
    }

    function goBack() {
        if (!history.length) return;
        navigationRevision++;
        pendingRequestId = -1; // ignore replies for a folder we already left
        const previous = history[history.length - 1];
        history = history.slice(0, history.length - 1);
        folderId = previous.id;
        folderType = previous.type;
        currentContainer = previous.container;
        browseItems = previous.items.slice();
        pageNumber = previous.page;
        requestedPage = previous.page;
        hasMore = previous.more;
        loading = false;
        loadingMore = false;
        errorMessage = "";
        const revision = navigationRevision;
        const indexToRestore = previous.index;
        Qt.callLater(function() {
            if (browser.browserActive && revision === browser.navigationRevision &&
                    carousel.count)
                carousel.currentIndex = Math.max(0, Math.min(indexToRestore, carousel.count - 1));
        });
        // If we left a level before its first response, load it afresh.
        if (!browseItems.length && !currentContainer && canBrowse)
            requestPage(1);
    }

    function loadMore() {
        if (!hasMore || loading || loadingMore || !browserActive) return;
        requestPage(pageNumber + 1);
    }

    function activateItem(item, index) {
        if (!item || !player || !browserActive) return;
        // Native MediaBrowser enters a browseable item with a single tap.
        // The inline PathView formerly required a second tap if it wasn't
        // already centered, making deep browsing appear unresponsive.
        if ((item.can_browse || (item.items && item.items.length)) &&
                !item.__containerPlay && (item.media_id || (item.items && item.items.length))) {
            enterFolder(item);
            return;
        }
        if (index !== carousel.currentIndex) {
            carousel.currentIndex = index;
            return;
        }
        if (item.can_play) {
            // PLAY_NOW is optional; normal play_media works on older integrations.
            if (player.hasFeature(MediaPlayerFeatures.Play_media_action) &&
                    item.play_media_action && item.play_media_action.indexOf("PLAY_NOW") >= 0)
                player.playMedia(item.media_id, item.media_type || "", "PLAY_NOW");
            else
                player.playMedia(item.media_id, item.media_type || "");
        }
    }

    function acceptResult(requestId, media, pagination) {
        if (!browserActive || requestId < 0 || requestId !== pendingRequestId) {
            console.log("Inline MB ignored old browse reply:", requestId,
                        "pending:", pendingRequestId);
            return;
        }
        pendingRequestId = -1;
        const incoming = media && media.items ? media.items : [];
        const append = loadingMore && requestedPage > 1;
        const selected = append ? carousel.currentIndex : 0;
        const revision = navigationRevision;
        // The root response is the root browse container, not an item to
        // display. Inside folders retain the returned album/playlist metadata.
        if (history.length) {
            // Browse responses may omit fields already provided by the
            // selected folder: retain media_id, media_type, playability and
            // artwork for the playlist/album header.
            const previousContainer = currentContainer || {};
            currentContainer = Object.assign({}, previousContainer, media || {});
            if (!currentContainer.media_id) currentContainer.media_id = folderId;
            if (!currentContainer.media_type) currentContainer.media_type = folderType;
            if (!currentContainer.thumbnail)
                currentContainer.thumbnail = previousContainer.thumbnail || "";
            if (!currentContainer.title)
                currentContainer.title = previousContainer.title || "";
            if (previousContainer.can_play)
                currentContainer.can_play = true;
            if (!currentContainer.media_class)
                currentContainer.media_class = previousContainer.media_class || "";
        } else {
            currentContainer = null;
        }
        restoringModel = true;
        // Preserve embedded children if the server reports an empty page.
        browseItems = append ? browseItems.concat(incoming)
                    : (incoming.length ? incoming.slice() : browseItems);
        pageNumber = requestedPage;
        hasMore = incoming.length > 0 && (pagination && pagination.count > 0
                  ? browseItems.length < pagination.count : incoming.length >= pageSize);
        loading = false;
        loadingMore = false;
        errorMessage = "";
        console.log("Inline MB accepted browse reply:", requestId,
                    "depth:", history.length, "children:", incoming.length,
                    "container:", media ? media.media_class : "");
        Qt.callLater(function() {
            if (browser.browserActive && revision === browser.navigationRevision && carousel.count)
                carousel.currentIndex = Math.max(0, Math.min(selected, carousel.count - 1));
            if (revision === browser.navigationRevision)
                browser.restoringModel = false;
        });
    }

    function acceptError(requestId, code, message) {
        if (!browserActive ||
                (requestId !== pendingRequestId && !(requestId < 0 && loading)))
            return;
        pendingRequestId = -1;
        loading = false;
        loadingMore = false;
        hasMore = false;
        // The server may legitimately have no children for a playable
        // playlist. Preserve its metadata, and show the playable cover.
        if (code === 404) {
            if (!browseItems.length && (!currentContainer || !currentContainer.can_play))
                errorMessage = qsTr("This folder has no media");
        } else {
            errorMessage = message || qsTr("Unable to browse media");
        }
        console.warn("Inline MB browse failed:", requestId, code, errorMessage);
    }

    function imageUrl(item) {
        const url = item && item.thumbnail ? item.thumbnail : "";
        if (!url || url.indexOf("icon://") === 0) return "";
        try { return decodeURIComponent(url); }
        catch (e) { return url; }
    }

    Component.onCompleted: resolveTarget()
    onEntitySelectorChanged: resolveTarget()
    onCommandEntityIdChanged: if (!entitySelector) resolveTarget()
    onActivityEntityChanged: if (!entitySelector) resolveTarget()
    onEntityIdChanged: bindPlayer()
    onPlayerChanged: if (browserActive) reload()
    onCanBrowseChanged: {
        // A media player may become available after the activity page opens.
        if (browserActive && canBrowse && !browseItems.length && pendingRequestId < 0)
            requestPage(1);
    }
    onBrowserActiveChanged: {
        if (browserActive) {
            resolveTarget();
            if (player && pendingRequestId < 0) reload();
        } else {
            pendingRequestId = -1;
        }
    }
    Connections {
        target: activityEntity
        ignoreUnknownSignals: true
        function onUiConfigChanged() { if (!browser.entitySelector) browser.resolveTarget(); }
        function onSliderConfigChanged() { if (!browser.entitySelector) browser.resolveTarget(); }
    }
    Connections {
        target: Config
        ignoreUnknownSignals: true
        function onActivityArtworkSourcesChanged() {
            if (!browser.entitySelector) browser.resolveTarget();
        }
    }
    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (!success) return;
            if (id === browser.entityId) browser.bindPlayer();
            else if (!browser.entityId) browser.resolveTarget();
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
        id: coverflowRegion
        anchors {
            top: parent.top
            bottom: metadata.top
            left: parent.left
            right: parent.right
        }
        clip: true

        PathView {
            id: carousel
            anchors.fill: parent
            visible: browser.hasArtworkRoom && browser.displayItems.length > 0
            clip: true
            model: browser.displayItems
            interactive: browser.browserActive && browser.displayItems.length > 1
            pathItemCount: Math.min(5, browser.displayItems.length)
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapOneItem
            // PathView is cyclic by design: no first/last sentinel or dead end.
            onCurrentIndexChanged: {
                if (!browser.restoringModel && browser.browseItems.length &&
                        currentIndex >= browser.browseItems.length - 3)
                    browser.loadMore();
            }

            path: Path {
                startX: -browser.artSize * 0.12
                startY: coverflowRegion.height / 2
                PathAttribute { name: "coverScale"; value: 0.56 }
                PathAttribute { name: "coverAngle"; value: 42 }
                PathAttribute { name: "coverDepth"; value: 1 }
                PathAttribute { name: "coverOpacity"; value: 0.60 }

                PathLine { x: coverflowRegion.width * 0.22; y: coverflowRegion.height / 2 }
                PathAttribute { name: "coverScale"; value: 0.72 }
                PathAttribute { name: "coverAngle"; value: 28 }
                PathAttribute { name: "coverDepth"; value: 10 }
                PathAttribute { name: "coverOpacity"; value: 0.78 }

                PathLine { x: coverflowRegion.width / 2; y: coverflowRegion.height / 2 }
                PathAttribute { name: "coverScale"; value: 1.0 }
                PathAttribute { name: "coverAngle"; value: 0 }
                PathAttribute { name: "coverDepth"; value: 30 }
                PathAttribute { name: "coverOpacity"; value: 1.0 }

                PathLine { x: coverflowRegion.width * 0.78; y: coverflowRegion.height / 2 }
                PathAttribute { name: "coverScale"; value: 0.72 }
                PathAttribute { name: "coverAngle"; value: -28 }
                PathAttribute { name: "coverDepth"; value: 10 }
                PathAttribute { name: "coverOpacity"; value: 0.78 }

                PathLine { x: coverflowRegion.width + browser.artSize * 0.12; y: coverflowRegion.height / 2 }
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
                    axis: Qt.vector3d(0, 1, 0)
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
                  : browser.selectionMessage ? browser.selectionMessage
                  : !browser.entityId ? qsTr("Use MB or MB;short_id")
                  : !browser.player ? qsTr("Media player unavailable")
                  : !browser.canBrowse ? qsTr("Media browsing unsupported")
                  : browser.errorMessage ? browser.errorMessage
                  : browser.loading ? qsTr("Loading media…")
                   : browser.history.length && browser.currentContainer
                     ? qsTr("This folder has no media") : qsTr("No media found")
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

    // Navigation is only shown inside a folder. At the root there is no
    // toolbar, title, refresh action, or reserved vertical header space.
    Item {
        id: backButton
        z: 2
        anchors { top: parent.top; left: parent.left; topMargin: 4; leftMargin: 4 }
        width: 44
        height: 44
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
        spacing: 0
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
                  ? (browser.currentItem.__containerPlay
                     ? qsTr("Tap cover to play") :
                     browser.currentItem.subtitle || browser.currentItem.artist ||
                     browser.currentItem.album || "") : ""
            font: fonts.help()
            color: colors.light
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }
}
