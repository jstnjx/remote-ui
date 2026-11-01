// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Entity.MediaPlayer 1.0
import "qrc:/components" as Components
import "qrc:/components/entities/media_player" as MediaPlayerComponents

// Stock-style media: flat surface, native text roles and focus fill.
Rectangle {
    id: card
    color: colors.surface
    radius: ui.cornerRadiusSmall
    property var player: null
    property bool large: false
    property bool selected: false
    property var openPlayer: function() {}

    Components.Selectable {
        selected: card.selected
        style: "fill"
    }

    Item {
        id: artContainer
        width: large ? Math.min(card.width - 40, 220) : 110
        height: width
        anchors {
            horizontalCenter: large ? parent.horizontalCenter : undefined
            left: large ? undefined : parent.left
            leftMargin: large ? 0 : 20
            top: parent.top
            topMargin: 20
        }
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

    Text {
        id: titleLabel
        width: large ? parent.width - 40 : parent.width - 170
        anchors {
            top: large ? artContainer.bottom : parent.top
            topMargin: large ? 14 : 20
            left: large ? parent.left : artContainer.right
            leftMargin: large ? 20 : 20
        }
        text: card.player && card.player.mediaTitle ? card.player.mediaTitle : qsTr("Nothing playing")
        font: fonts.label()
        color: colors.textPrimary
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.WordWrap
        horizontalAlignment: large ? Text.AlignHCenter : Text.AlignLeft
    }
    Text {
        id: artistLabel
        anchors { top: titleLabel.bottom; topMargin: 4; left: titleLabel.left }
        width: titleLabel.width
        text: card.player ? card.player.mediaArtist || "" : ""
        font: fonts.help()
        color: colors.textSecondary
        maximumLineCount: 1
        elide: Text.ElideRight
        horizontalAlignment: large ? Text.AlignHCenter : Text.AlignLeft
    }

    Row {
        spacing: large ? 20 : 8
        anchors {
            horizontalCenter: large ? parent.horizontalCenter : undefined
            right: large ? undefined : parent.right
            rightMargin: large ? 0 : 15
            bottom: parent.bottom
            bottomMargin: large ? 20 : 14
        }
        Repeater {
            model: ["uc:backward-step", "uc:play", "uc:forward-step"]
            delegate: Item {
                width: 60
                height: 60
                Components.Icon {
                    anchors.centerIn: parent
                    icon: index === 1 && card.player && card.player.state === MediaPlayerStates.Playing ?
                          "uc:pause" : modelData
                    color: colors.textPrimary
                    size: 60
                }
                Components.HapticMouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!card.player || !card.player.enabled) return;
                        if (index === 0) card.player.previous();
                        else if (index === 1) card.player.playPause();
                        else card.player.next();
                    }
                }
            }
        }
    }
    Components.HapticMouseArea {
        width: titleLabel.width
        height: Math.max(80, artistLabel.y + artistLabel.height - titleLabel.y)
        x: titleLabel.x
        y: titleLabel.y
        onClicked: card.openPlayer()
    }
}
