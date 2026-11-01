// Copyright (c) 2022-2023 Unfolded Circle ApS and/or its affiliates. <hello@unfoldedcircle.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15

import Battery 1.0
import Config 1.0

import "qrc:/components" as Components

Popup {
    id: chargingScreenRoot
    width: ui.width; height: ui.height
    opacity: 0
    modal: false
    closePolicy: Popup.CloseOnPressOutside
    padding: 0

    onOpened: {
        buttonNavigation.takeControl();
    }

    onClosed: {
        buttonNavigation.releaseControl();
    }

    Components.ButtonNavigation {
        id: buttonNavigation
        defaultConfig: {
            "BACK": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "HOME": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "VOICE": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "VOLUME_UP": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "VOLUME_DOWN": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "GREEN": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "DPAD_UP": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "YELLOW": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "DPAD_LEFT": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "DPAD_MIDDLE": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "DPAD_RIGHT": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "RED": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "DPAD_DOWN": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "BLUE": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "CHANNEL_UP": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "CHANNEL_DOWN": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "MUTE": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "PREV": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "PLAY": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "NEXT": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "POWER": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "STOP": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "RECORD": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            },
            "MENU": {
                "pressed": function() {
                    chargingScreenRoot.close();
                }
            }
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.OutExpo; duration: 300 }
        PropertyAnimation { target: chargeIndicator; properties: "anchors.bottomMargin"; to: 0; easing.type: Easing.OutExpo; duration: 500 }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.OutExpo; duration: 300 }
        PropertyAnimation { target: chargeIndicator; properties: "anchors.bottomMargin"; to: -100; easing.type: Easing.OutExpo; duration: 500 }
    }

    background: Rectangle { color: colors.black }

    MouseArea {
        anchors.fill: parent
        onClicked: chargingScreenRoot.close()
    }

    Item {
        id: clock
        width: ui.width-80; height: width
        visible: !Config.digitalScreensaverClock
        anchors.centerIn: parent

        property int hours: ui.time.getHours()
        property int minutes: ui.time.getMinutes()
        property int seconds: ui.time.getSeconds()

        Repeater {
            model: 12

            Item {
                id: dotContainer
                height: parent.height/2
                transformOrigin:  Item.Bottom
                rotation: index * 30
                x: parent.width/2
                y: 0

                Rectangle {
                    width: 12; height: 12
                    radius: 6
                    color: colors.offwhite
                    opacity: index == 0 || index == 3 || index == 6 || index ==9 ? 1 : 0.6
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 4 }
                }
            }
        }

        Item {
            id: seconds
            anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }

            property int value: clock.seconds
            property int granularity: 60

            Rectangle {
                width: 1; height: clock.width/2 - 20
                color: colors.red
                anchors { horizontalCenter: parent.horizontalCenter }
                antialiasing: true
                y: parent.height * 0.05
            }
            rotation: 360/granularity * (value % granularity)
            antialiasing: true

            //            Behavior on rotation {
            //                NumberAnimation { duration: 1000 }
            //            }
        }

        Item {
            id: minutes
            anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }

            property int value: clock.minutes
            property int granularity: 60

            Rectangle {
                width: 4; height: clock.width/2 - 40
                color: colors.offwhite
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.verticalCenter }
                antialiasing: true
            }
            rotation: 360/granularity * (value % granularity)
            antialiasing: true
        }

        Item {
            id: hours
            anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }

            property int value: clock.hours
            property int valueMinute: clock.minutes
            property int granularity: 12

            Rectangle {
                width: 4; height: clock.width/2 - 80
                color: colors.offwhite
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.verticalCenter }
                antialiasing: true
            }
            rotation: 360/granularity * (value % granularity) + 360 / granularity * (valueMinute / 60)
            antialiasing: true
        }

    }

    // Minimal charging clock, styled after the Remote 3 reference: ample
    // black space, lightweight time at lower left and a fine battery rail.
    Item {
        id: digitalClock
        anchors.fill: parent
        visible: Config.digitalScreensaverClock

        Column {
            id: digitalTimeGroup
            x: 20
            y: parent.height * 0.62
            width: parent.width - 92
            spacing: 3

            Text {
                width: parent.width
                text: Qt.formatTime(ui.time, Config.clock24h ? "HH:mm" : "hh:mm AP")
                color: colors.offwhite
                font: fonts.primaryFont(77)
                font.weight: Font.Light
                fontSizeMode: Text.Fit
                minimumPixelSize: 38
                horizontalAlignment: Text.AlignLeft
            }

            Text {
                width: parent.width
                text: Qt.formatDate(ui.time, "dddd").toLowerCase()
                color: colors.offwhite
                font: fonts.primaryFont(22)
                font.weight: Font.Light
            }

            Text {
                width: parent.width
                text: Qt.formatDate(ui.time, "d MMMM yyyy").toLowerCase()
                color: colors.offwhite
                font: fonts.primaryFont(22)
                font.weight: Font.Light
            }
        }

        // Narrow right-hand charge indicator. The bottom-anchored fill tracks
        // the actual battery level; status stays visible even at 0%.
        Item {
            id: chargeRail
            x: parent.width - 25
            y: 45
            width: 3
            height: parent.height * 0.79

            Rectangle {
                anchors.fill: parent
                color: colors.dark
                radius: 2
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * Math.max(0, Math.min(100, Battery.level)) / 100
                radius: 2
                color: colors.green
            }
        }

        Components.Icon {
            icon: Battery.isCharging ? "uc:bolt" : "uc:battery-full"
            color: colors.green
            size: 22
            anchors { top: parent.top; topMargin: 14; right: chargeRail.right }
        }

        Text {
            text: Battery.level + "%"
            color: colors.green
            font: fonts.primaryFont(22)
            font.weight: Font.Light
            anchors { top: chargeRail.top; topMargin: 75; right: chargeRail.left; rightMargin: 6 }
        }
    }

    Item {
        id: chargeIndicator
        visible: !Config.digitalScreensaverClock
        width: childrenRect.width
        height: 70
        anchors { bottom: parent.bottom; bottomMargin: -100; horizontalCenter: parent.horizontalCenter }

        Components.Icon {
            id: icon
            icon: "uc:bolt"
            color: colors.offwhite
            anchors { left: parent.left; leftMargin: -10 }
            size: 60
        }

        Text {
            color: colors.offwhite
            text: Battery.level + "% " + (Battery.isCharging ? qsTr("- Charging") : "")
            anchors { left: icon.right; leftMargin: 10; verticalCenter: icon.verticalCenter }
            font: fonts.primaryFont(24)
        }
    }

}
