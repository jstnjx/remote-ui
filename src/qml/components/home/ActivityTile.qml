// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Entity.Controller 1.0
import "qrc:/components" as Components

// Native tile with two bounded layouts. Narrow dock/quick-control tiles
// intentionally show only the icon: a 30px label cannot fit in 100px width.
Rectangle {
    id: tile
    radius: ui.cornerRadiusSmall
    color: colors.surface
    clip: true

    property string entityId: ""
    property bool selected: false
    property bool compact: false
    readonly property bool iconOnly: compact && width < 170
    property var entityObj: EntityController.get(entityId)
    signal triggered(string id)

    onEntityIdChanged: entityObj = EntityController.get(entityId)

    Components.Selectable {
        selected: tile.selected
        style: "fill"
    }

    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (success && id === tile.entityId)
                tile.entityObj = EntityController.get(id);
        }
    }

    Column {
        visible: !tile.compact
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 20)
        spacing: 3

        Components.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: tile.entityObj && tile.entityObj.icon ? tile.entityObj.icon : "uc:tv"
            size: 68
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

    Row {
        visible: tile.compact
        anchors.centerIn: parent
        height: 64
        width: tile.iconOnly ? 64 : Math.max(0, tile.width - 20)
        spacing: 8

        Components.Icon {
            id: compactIcon
            icon: tile.entityObj && tile.entityObj.icon ? tile.entityObj.icon : "uc:tv"
            size: 60
            color: colors.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: !tile.iconOnly
            width: Math.max(0, parent.width - compactIcon.width - parent.spacing)
            anchors.verticalCenter: parent.verticalCenter
            text: tile.entityObj ? tile.entityObj.name : qsTr("Activity")
            font: fonts.label()
            color: colors.textPrimary
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }

    Components.HapticMouseArea {
        anchors.fill: parent
        onClicked: tile.triggered(tile.entityId)
    }
}
