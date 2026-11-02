// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import "qrc:/components" as Components
import "qrc:/components/entities/media_player" as MediaPlayerComponents

// One compact, control-free now-playing strip for the active activity.
Rectangle {
    id: card
    color: colors.surface
    radius: 0
    clip: true

    property var player: null
    property var openPlayer: function() {}

    Row {
        id: content
        anchors.fill: parent
        spacing: 0

        Item {
            id: artworkSlot
            width: Math.max(0, content.width / 3)
            height: content.height
            clip: true

            MediaPlayerComponents.ImageLoader {
                anchors.fill: parent
                url: card.player && card.player.mediaImage ? card.player.mediaImage : ""
                aspectFit: false
                alignCentered: true
            }
            Components.Icon {
                anchors.centerIn: parent
                visible: !card.player || !card.player.mediaImage
                icon: "uc:music"
                size: Math.min(parent.height, 58)
                color: colors.textSecondary
            }
        }

        Column {
            width: Math.max(0, content.width - artworkSlot.width - 18)
            x: artworkSlot.width + 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: card.player && card.player.mediaTitle ? card.player.mediaTitle : qsTr("Nothing playing")
                font: fonts.label()
                color: colors.textPrimary
                maximumLineCount: 1
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: card.player ? card.player.mediaArtist || card.player.name || "" : ""
                font: fonts.help()
                color: colors.textSecondary
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }
    }

    Components.HapticMouseArea {
        anchors.fill: parent
        onClicked: card.openPlayer()
    }
}
