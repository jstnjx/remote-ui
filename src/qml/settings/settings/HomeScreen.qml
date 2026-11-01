// Copyright (c) 2026 jstnjx
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Config 1.0
import "qrc:/settings" as Settings
import "qrc:/components" as Components

Settings.Page {
    id: homeSettings
    scrollTarget: flickable
    initialFocusItem: enabledSwitch
    readonly property var layoutNames: [
        qsTr("Modern Grid"), qsTr("Media Focus"),
        qsTr("Living Room Hub"), qsTr("Minimal")
    ]

    Flickable {
        id: flickable
        anchors { left: parent.left; right: parent.right; top: topNavigation.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: settingsColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsColumn
            width: parent.width
            spacing: 0

            Components.SettingRow {
                title: qsTr("Use redesigned home screen")
                help: qsTr("Show the optional new layout on the first page. Turn this off to restore the original home screen immediately.")
                Components.Switch {
                    id: enabledSwitch
                    icon: "uc:check"
                    checked: Config.redesignedHomeEnabled
                    trigger: function() { Config.redesignedHomeEnabled = !Config.redesignedHomeEnabled; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.down: layoutSlider
                }
            }

            Components.SettingRow {
                title: qsTr("Home layout")
                help: qsTr("Choose how activities, media and controls are arranged.")
                value: homeSettings.layoutNames[Config.homeScreenLayout]
                controlBelow: true
                controlBottomSpace: 40
                Components.Slider {
                    id: layoutSlider
                    height: 60
                    from: 0; to: 3; stepSize: 1
                    value: Config.homeScreenLayout
                    lowValueText: qsTr("Modern Grid")
                    highValueText: qsTr("Minimal")
                    onUserInteractionEnded: Config.homeScreenLayout = Math.round(value)
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: enabledSwitch
                    KeyNavigation.down: clockSwitch
                }
            }

            Components.SettingRow {
                title: qsTr("Show clock and date")
                Components.Switch {
                    id: clockSwitch
                    icon: "uc:check"
                    checked: Config.homeShowClock
                    trigger: function() { Config.homeShowClock = !Config.homeShowClock; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: layoutSlider
                    KeyNavigation.down: activitiesSwitch
                }
            }
            Components.SettingRow {
                title: qsTr("Show activity shortcuts")
                Components.Switch {
                    id: activitiesSwitch
                    icon: "uc:check"
                    checked: Config.homeShowActivities
                    trigger: function() { Config.homeShowActivities = !Config.homeShowActivities; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: clockSwitch
                    KeyNavigation.down: mediaSwitch
                }
            }
            Components.SettingRow {
                title: qsTr("Show now playing")
                Components.Switch {
                    id: mediaSwitch
                    icon: "uc:check"
                    checked: Config.homeShowMedia
                    trigger: function() { Config.homeShowMedia = !Config.homeShowMedia; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: activitiesSwitch
                    KeyNavigation.down: quickSwitch
                }
            }
            Components.SettingRow {
                title: qsTr("Show quick controls")
                help: qsTr("Shortcuts to configured lights and switches; displays a settings shortcut when none exist.")
                Components.Switch {
                    id: quickSwitch
                    icon: "uc:check"
                    checked: Config.homeShowQuickControls
                    trigger: function() { Config.homeShowQuickControls = !Config.homeShowQuickControls; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: mediaSwitch
                    KeyNavigation.down: dotsSwitch
                }
            }
            Components.SettingRow {
                showDivider: false
                title: qsTr("Show page indicators")
                Components.Switch {
                    id: dotsSwitch
                    icon: "uc:check"
                    checked: Config.homeShowPageIndicators
                    trigger: function() { Config.homeShowPageIndicators = !Config.homeShowPageIndicators; }
                    highlight: activeFocus && ui.keyNavigationActive
                    KeyNavigation.up: quickSwitch
                }
            }
        }
    }
}
