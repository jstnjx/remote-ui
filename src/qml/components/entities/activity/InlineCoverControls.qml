// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import Entity.Cover 1.0
import "qrc:/components" as Components
import "qrc:/components/entities/cover" as CoverComponents

// Reuses the native Cover OpenClose component for binary covers. Positional
// covers use the native cover detail's 0..100 position and Open/Stop/Close
// commands with a compact proportional track instead of hardcoded 500px.
Item {
    id: controls
    property var entityObj: null
    property bool acceptsCommands: false
    readonly property bool positional: entityObj && entityObj.hasFeature(CoverFeatures.Position)

    CoverComponents.OpenClose {
        anchors.fill: parent
        entityObj: controls.entityObj
        compact: true
        visible: !controls.positional && controls.entityObj !== null
        enabled: controls.acceptsCommands
    }

    Column {
        anchors.fill: parent
        spacing: 8
        visible: controls.positional
        Text {
            width: parent.width
            text: controls.entityObj && controls.entityObj.positionAvailable ?
                  qsTr("%1%").arg(Math.round(coverPosition.value)) : "--"
            font: fonts.primaryFont(44, "Light")
            color: colors.offwhite
        }
        Slider {
            id: coverPosition
            width: parent.width
            height: Math.max(50, controls.height - 113)
            from: 0
            to: 100
            stepSize: 1
            snapMode: Slider.SnapAlways
            enabled: controls.acceptsCommands && controls.positional
            value: controls.entityObj && controls.entityObj.positionAvailable ?
                   controls.entityObj.position : 0
            property bool changedByUser: false
            onMoved: changedByUser = true
            onPressedChanged: {
                if (!pressed && changedByUser) {
                    changedByUser = false;
                    if (controls.acceptsCommands && controls.positional)
                        controls.entityObj.setPosition(Math.round(value));
                }
            }
            background: Rectangle {
                x: coverPosition.leftPadding
                y: coverPosition.topPadding + coverPosition.availableHeight / 2 - height / 2
                width: coverPosition.availableWidth
                height: 44
                radius: ui.cornerRadiusSmall
                color: colors.dark
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: coverPosition.visualPosition * parent.width
                    radius: ui.cornerRadiusSmall
                    color: colors.offwhite
                }
            }
            handle: Rectangle {
                x: coverPosition.leftPadding + coverPosition.visualPosition *
                   (coverPosition.availableWidth - width)
                y: coverPosition.topPadding + coverPosition.availableHeight / 2 - height / 2
                width: 14
                height: 52
                radius: 6
                color: colors.light
            }
        }
        Row {
            width: parent.width
            height: 42
            spacing: 6
            Repeater {
                model: [
                    {label: qsTr("Open"), icon: "uc:arrow-up", action: "open"},
                    {label: qsTr("Stop"), icon: "uc:stop", action: "stop"},
                    {label: qsTr("Close"), icon: "uc:arrow-down", action: "close"}
                ]
                delegate: Rectangle {
                    width: (parent.width - 12) / 3
                    height: 42
                    radius: ui.cornerRadiusSmall
                    color: colors.medium
                    Components.Icon {
                        icon: modelData.icon
                        color: colors.offwhite
                        size: 32
                        anchors.centerIn: parent
                    }
                    Components.HapticMouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        enabled: controls.acceptsCommands && controls.entityObj &&
                            ((modelData.action === "open" &&
                              controls.entityObj.hasFeature(CoverFeatures.Open)) ||
                             (modelData.action === "close" &&
                              controls.entityObj.hasFeature(CoverFeatures.Close)) ||
                             (modelData.action === "stop" &&
                              controls.entityObj.hasFeature(CoverFeatures.Stop)))
                        onClicked: {
                            if (modelData.action === "open") controls.entityObj.open();
                            else if (modelData.action === "stop") controls.entityObj.stop();
                            else controls.entityObj.close();
                        }
                    }
                }
            }
        }
    }
}
