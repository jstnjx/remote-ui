// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Entity.Controller 1.0
import "qrc:/components" as Components

// Transparent bottom launcher: no cards, backgrounds or borders.
Item {
    id: tile
    clip: true

    property string entityId: ""
    property bool selected: false
    property bool showLabel: true
    property var entityObj: EntityController.get(entityId)
    signal triggered(string id)

    onEntityIdChanged: entityObj = EntityController.get(entityId)
    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (success && id === tile.entityId)
                tile.entityObj = EntityController.get(id);
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 4

        Components.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: tile.entityObj && tile.entityObj.icon ? tile.entityObj.icon : "uc:tv"
            size: Math.min(68, tile.height - (tile.showLabel ? 32 : 8))
            color: colors.textPrimary
            opacity: tile.selected ? 1.0 : 0.9
        }
        Text {
            visible: tile.showLabel
            width: parent.width
            text: tile.entityObj ? tile.entityObj.name : qsTr("Activity")
            font: fonts.help()
            color: tile.selected ? colors.textPrimary : colors.textSecondary
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }

    Components.HapticMouseArea {
        anchors.fill: parent
        onClicked: tile.triggered(tile.entityId)
    }
}
