// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Entity.MediaPlayer 1.0
import "qrc:/components" as Components
import "qrc:/components/entities/media_player" as MediaPlayerComponents

// Compact and expanded compositions have separate, non-overlapping regions.
// Never position transport controls over dynamic title or artist text.
Rectangle {
    id: card
    color: colors.surface
    radius: ui.cornerRadiusSmall
    clip: true

    property var player: null
    property bool large: false
    property bool selected: false
    property var openPlayer: function() {}

    Components.Selectable {
        selected: card.selected
        style: "fill"
    }

    // Compact: 100px artwork on the left, one-line metadata above controls.
    Item {
        id: compactLayout
        anchors.fill: parent
        visible: !card.large

        Item {
            width: Math.min(100, Math.max(64, compactLayout.width * 0.27))
            height: width
            x: 16
            y: 16

            MediaPlayerComponents.ImageLoader {
                anchors.fill: parent
                url: card.player && card.player.mediaImage ? card.player.mediaImage : ""
                aspectFit: true
                alignCentered: true
            }
            Components.Icon {
                anchors.centerIn: parent
                visible: !card.player || !card.player.mediaImage
                icon: "uc:music"
                size: Math.min(parent.width, 100)
                color: colors.textPrimary
            }
        }

        Column {
            x: Math.min(100, Math.max(64, compactLayout.width * 0.27)) + 32
            y: 16
            width: Math.max(0, compactLayout.width - x - 16)
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
                text: card.player ? card.player.mediaArtist || "" : ""
                font: fonts.help()
                color: colors.textSecondary
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }

        Row {
            id: compactTransport
            x: Math.min(100, Math.max(64, compactLayout.width * 0.27)) + 32
            y: Math.max(92, compactLayout.height - height - 12)
            spacing: 12
            Repeater {
                model: 3
                delegate: Item {
                    width: Math.max(44, Math.min(60, (compactLayout.width - compactTransport.x -
                                                      16 - 2 * compactTransport.spacing) / 3))
                    height: 60
                    Components.Icon {
                        anchors.centerIn: parent
                        icon: index === 0 ? "uc:backward-step" :
                              index === 2 ? "uc:forward-step" :
                              card.player && card.player.state === MediaPlayerStates.Playing ? "uc:pause" : "uc:play"
                        color: colors.textPrimary
                        size: Math.min(60, parent.width)
                    }
                    Components.HapticMouseArea {
                        anchors.fill: parent
                        onClicked: card.transport(index)
                    }
                }
            }
        }

        Components.HapticMouseArea {
            x: compactTransport.x
            y: 0
            width: Math.max(0, parent.width - x)
            height: Math.min(92, parent.height)
            onClicked: card.openPlayer()
        }
    }

    // Expanded: artwork, title and transport each have their own vertical band.
    Item {
        id: expandedLayout
        anchors.fill: parent
        visible: card.large

        Item {
            id: bigArtwork
            width: Math.min(170, expandedLayout.width - 40)
            height: width
            anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }

            MediaPlayerComponents.ImageLoader {
                anchors.fill: parent
                url: card.player && card.player.mediaImage ? card.player.mediaImage : ""
                aspectFit: true
                alignCentered: true
            }
            Components.Icon {
                anchors.centerIn: parent
                visible: !card.player || !card.player.mediaImage
                icon: "uc:music"
                size: 100
                color: colors.textPrimary
            }
        }

        Column {
            id: expandedMetadata
            anchors { top: bigArtwork.bottom; topMargin: 12; left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 20 }
            spacing: 4

            Text {
                width: parent.width
                text: card.player && card.player.mediaTitle ? card.player.mediaTitle : qsTr("Nothing playing")
                color: colors.textPrimary
                font: fonts.label()
                maximumLineCount: 2
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                text: card.player ? card.player.mediaArtist || "" : ""
                color: colors.textSecondary
                font: fonts.help()
                maximumLineCount: 1
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Row {
            anchors { bottom: parent.bottom; bottomMargin: 16; horizontalCenter: parent.horizontalCenter }
            spacing: 20
            Repeater {
                model: 3
                delegate: Item {
                    width: 64; height: 64
                    Components.Icon {
                        anchors.centerIn: parent
                        icon: index === 0 ? "uc:backward-step" :
                              index === 2 ? "uc:forward-step" :
                              card.player && card.player.state === MediaPlayerStates.Playing ? "uc:pause" : "uc:play"
                        color: colors.textPrimary
                        size: 64
                    }
                    Components.HapticMouseArea {
                        anchors.fill: parent
                        onClicked: card.transport(index)
                    }
                }
            }
        }
        Components.HapticMouseArea {
            x: 20
            y: bigArtwork.y
            width: parent.width - 40
            height: Math.max(0, expandedMetadata.y + expandedMetadata.height - bigArtwork.y)
            onClicked: card.openPlayer()
        }
    }

    function transport(index) {
        if (!player || !player.enabled) return;
        if (index === 0) player.previous();
        else if (index === 1) player.playPause();
        else player.next();
    }
}
