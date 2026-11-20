// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import Entity.Controller 1.0
import Config 1.0

import "qrc:/components" as Components
import "qrc:/components/entities/media_player" as MediaPlayerComponents

// Live, artwork-only activity widget. The containing Text button is replaced
// entirely; there is no playback control, popup, caption or extra border.
Item {
    id: artworkWidget
    clip: true

    property string entityId: ""
    property var entityObj: null

    function loadEntity() {
        if (!entityId) {
            entityObj = null;
            return;
        }
        const found = EntityController.get(entityId);
        entityObj = found && found.type === EntityTypes.Media_player ? found : null;
        if (!found) EntityController.load(entityId);
    }

    Component.onCompleted: loadEntity()
    onEntityIdChanged: loadEntity()

    Connections {
        target: EntityController
        ignoreUnknownSignals: true
        function onEntityLoaded(success, loadedId) {
            if (success && loadedId === artworkWidget.entityId)
                artworkWidget.loadEntity();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: colors.surface
        radius: ui.cornerRadiusSmall
        clip: true

        MediaPlayerComponents.ImageLoader {
            id: artwork
            anchors.fill: parent
            url: artworkWidget.entityObj && artworkWidget.entityObj.mediaImage
                 ? artworkWidget.entityObj.mediaImage : ""
            aspectFit: !Config.fillMediaArtwork
            alignCentered: true
        }

        Components.Icon {
            anchors.centerIn: parent
            icon: "uc:music"
            color: colors.light
            size: Math.max(0, Math.min(parent.width, parent.height, 80) * 0.50)
            visible: !artwork.url || artwork.failed
        }
    }
}
