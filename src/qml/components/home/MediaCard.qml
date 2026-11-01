// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Entity.MediaPlayer 1.0
import "qrc:/components" as Components
import "qrc:/components/entities/media_player" as MediaPlayerComponents

Rectangle {
    id: card
    color: colors.dark
    radius: ui.cornerRadiusSmall
    property var player: null
    property bool large: false
    property bool selected: false
    property var openPlayer: function() {}
    border.color: selected ? colors.offwhite : colors.divider
    border.width: selected ? 2 : 1

    Item {
        id: artContainer
        width: large ? Math.min(card.width - 64, 240) : 110
        height: large ? width : 110
        anchors {
            horizontalCenter: large ? parent.horizontalCenter : undefined
            left: large ? undefined : parent.left
            leftMargin: large ? 0 : 18
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
            size: large ? 92 : 72
            color: colors.offwhite
        }
    }

    Text {
        id: titleLabel
        width: large ? parent.width - 40 : parent.width - 165
        anchors {
            top: large ? artContainer.bottom : parent.top
            topMargin: large ? 20 : 20
            left: large ? parent.left : artContainer.right
            leftMargin: large ? 20 : 18
        }
        text: card.player && card.player.mediaTitle ? card.player.mediaTitle : qsTr("Nothing playing")
        font: fonts.primaryFont(large ? 28 : 23)
        color: colors.offwhite
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
        color: colors.light
        elide: Text.ElideRight
        horizontalAlignment: large ? Text.AlignHCenter : Text.AlignLeft
    }

    Row {
        id: transport
        spacing: 25
        anchors {
            horizontalCenter: large ? parent.horizontalCenter : undefined
            left: large ? undefined : titleLabel.left
            bottom: parent.bottom
            bottomMargin: large ? 24 : 20
        }
        Repeater {
            model: ["uc:backward-step", "uc:play-pause", "uc:forward-step"]
            delegate: Item {
                width: large ? 72 : 50
                height: large ? 72 : 50
                Components.Icon {
                    anchors.centerIn: parent
                    icon: index === 1 && card.player && card.player.state === MediaPlayerStates.Playing ?
                          "uc:pause" : index === 1 ? "uc:play" : modelData
                    color: colors.offwhite
                    size: large ? 55 : 42
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
