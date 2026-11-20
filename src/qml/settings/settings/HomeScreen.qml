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
                help: qsTr("Show the configured home page with a clock header, media strip and a single native entity list. Turn off to restore the original screen.")
                Components.Switch {
                    id: enabledSwitch
                    icon: "uc:check"
                    checked: Config.redesignedHomeEnabled
                    trigger: function() { Config.redesignedHomeEnabled = !Config.redesignedHomeEnabled; }
                    highlight: activeFocus && ui.keyNavigationActive
                 }
            }


        }
    }
}
