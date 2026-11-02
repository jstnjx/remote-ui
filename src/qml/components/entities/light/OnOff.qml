// Copyright (c) 2022-2023 Unfolded Circle ApS and/or its affiliates. <hello@unfoldedcircle.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15

import Entity.Light 1.0

import "qrc:/components" as Components

Item {
    id: onOffFeature
    anchors.fill: parent

    property QtObject entityObj
    property bool compact: false

    Text {
        //: Light device state
        text: entityObj.state === LightStates.On ? qsTr("On") : qsTr("Off")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        elide: Text.ElideRight
        maximumLineCount: 2
        color: colors.offwhite
        anchors { left: parent.left; leftMargin: onOffFeature.compact ? 6 : 30; right: parent.right; rightMargin: onOffFeature.compact ? 6 : 30; bottom: onOffButtonContainer.top }
        font: fonts.primaryFont(onOffFeature.compact ? 44 : 180, "Light")
    }

    Rectangle {
        id: onOffButtonContainer
        width: Math.max(40, parent.width - (onOffFeature.compact ? 12 : 60))
        height: onOffFeature.compact ? Math.min(width, parent.height * .64) : width
        radius: ui.cornerRadiusSmall
        color: colors.medium
        anchors { bottom: parent.bottom; bottomMargin: onOffFeature.compact ? 4 : 30; horizontalCenter: parent.horizontalCenter }

        states: State {
            name: "pressed"
            when: onOffMouseArea.pressed
            PropertyChanges {
                target: onOffButtonContainer
                color: colors.offwhite
            }
        }

        transitions: [
            Transition {
                from: ""; to: "pressed"; reversible: true
                PropertyAnimation { target: onOffButtonContainer
                    properties: "color"; duration: 300 }
            }]

        Rectangle {
            id: onOffButton
            width: parent.width - (onOffFeature.compact ? 12 : 60)
            height: onOffFeature.compact ? Math.min(width, parent.height - 12) : width
            radius: ui.cornerRadiusSmall
            color: entityObj.state === LightStates.On ? colors.offwhite : colors.dark
            anchors.centerIn: parent

            Behavior on color {
                ColorAnimation { duration: 300 }
            }
        }

        Components.HapticMouseArea {
            id: onOffMouseArea
            anchors.fill: parent
            onClicked: {
                entityObj.toggle();
            }
        }
    }
}
