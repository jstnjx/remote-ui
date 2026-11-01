// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Entity.Controller 1.0
import "qrc:/components" as Components

// Uses the same tokens, menu-tile fill selection and typography as stock Page.
Rectangle {
    id: tile
    radius: ui.cornerRadiusSmall
    color: colors.surface
    property string entityId: ""
    property bool selected: false
    property bool compact: false
    property var entityObj: EntityController.get(entityId)
    signal triggered(string id)

    onEntityIdChanged: entityObj = EntityController.get(entityId)

    Components.Selectable {
        // Must be under the tile's content, not a permanent white outline.
        selected: tile.selected
        style: "fill"
    }

    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (success && id === tile.entityId) {
                tile.entityObj = EntityController.get(id);
            }
        }
    }

    // Standard native tile: 100px icon box, 30px label, 26px state.
    Column {
        visible: !tile.compact
        anchors.centerIn: parent
        width: parent.width - 20
        spacing: 2

        Components.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: tile.entityObj && tile.entityObj.icon ? tile.entityObj.icon : "uc:tv"
            size: 100
            color: colors.textPrimary
        }
        Text {
            width: parent.width
            text: tile.entityObj ? tile.entityObj.name : qsTr("Activity")
            font: fonts.label()
            color: colors.textPrimary
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: tile.entityObj && tile.entityObj.stateAsString !== ""
            text: tile.entityObj ? tile.entityObj.stateAsString : ""
            font: fonts.help()
            color: colors.textSecondary
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }

    // Compact native row, falling back to an icon-only dock for narrow tiles.
    Row {
        visible: tile.compact
        anchors.centerIn: parent
        width: parent.width - 12
        height: 80
        spacing: 4
        Components.Icon {
            id: compactIcon
            icon: tile.entityObj && tile.entityObj.icon ? tile.entityObj.icon : "uc:tv"
            size: 60
            color: colors.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: tile.width >= 160
            width: Math.max(0, tile.width - compactIcon.width - 26)
            anchors.verticalCenter: parent.verticalCenter
            text: tile.entityObj ? tile.entityObj.name : qsTr("Activity")
            font: fonts.label()
            color: colors.textPrimary
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    Components.HapticMouseArea {
        anchors.fill: parent
        onClicked: tile.triggered(tile.entityId)
    }
}
