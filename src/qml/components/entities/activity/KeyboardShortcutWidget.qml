// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import "qrc:/components" as Components

// A popup-free icon widget. The two-character "KB" fits stock text limits.
Rectangle {
    id: widget
    color: colors.black
    radius: 0
    border.width: 0
    property var openKeyboard: function() {}

    Components.Icon {
        anchors.centerIn: parent
        icon: "uc:keyboard"
        size: Math.min(70, Math.min(widget.width, widget.height) - 12)
        color: colors.offwhite
    }
    Components.HapticMouseArea {
        anchors.fill: parent
        onClicked: widget.openKeyboard()
    }
}
