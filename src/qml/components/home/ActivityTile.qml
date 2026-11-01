// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Entity.Controller 1.0
import "qrc:/components" as Components

Rectangle {
    id: tile
    radius: ui.cornerRadiusSmall
    color: selected ? colors.medium : colors.dark
    border { width: selected ? 2 : 1; color: selected ? colors.offwhite : colors.divider }
    property string entityId: ""
    property bool selected: false
    property bool compact: false
    property var entityObj: EntityController.get(entityId)
    signal triggered(string id)

    onEntityIdChanged: entityObj = EntityController.get(entityId)
    Connections {
        target: EntityController
        function onEntityLoaded(success, id) {
            if (success && id === tile.entityId) tile.entityObj = EntityController.get(id);
        }
    }
    Column {
        width: parent.width - 16
        spacing: 5
        anchors.centerIn: parent
        Components.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: tile.entityObj && tile.entityObj.icon ? tile.entityObj.icon : "uc:tv"
            size: tile.compact ? 44 : 68
            color: colors.offwhite
        }
        Text {
            width: parent.width
            text: tile.entityObj ? tile.entityObj.name : qsTr("Activity")
            font: fonts.primaryFont(tile.compact ? 22 : 25)
            color: colors.offwhite
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            width: parent.width
            visible: !tile.compact && tile.entityObj && tile.entityObj.stateAsString !== ""
            text: tile.entityObj ? tile.entityObj.stateAsString : ""
            color: colors.light
            font: fonts.help()
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
    Components.HapticMouseArea {
        anchors.fill: parent
        onClicked: tile.triggered(tile.entityId)
    }
}
