// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Rtsp 1.0

Rectangle {
    id: widget
    color: "black"
    radius: 12
    clip: true

    property string streamUrl: ""
    property bool streamActive: false

    RtspStream {
        id: stream
        anchors.fill: parent
        source: widget.streamUrl
        active: widget.streamActive && widget.visible
    }

    // Match the remote's native LoadingScreen: two off-white dots rotating
    // with an OutSine easing and a short pause after each revolution.
    // This lives inside the tile rather than opening a full-screen popup.
    Item {
        id: loadingCircle
        width: Math.max(24, Math.min(100, widget.width - 20, widget.height - 20))
        height: width
        anchors.centerIn: parent
        visible: stream.active && !stream.playing && stream.error === ""

        Rectangle {
            width: Math.max(6, loadingCircle.width / 10)
            height: width
            radius: width / 2
            color: colors.offwhite
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        }

        Rectangle {
            width: Math.max(6, loadingCircle.width / 10)
            height: width
            radius: width / 2
            color: colors.offwhite
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        }

        SequentialAnimation {
            running: loadingCircle.visible
            loops: Animation.Infinite
            NumberAnimation {
                target: loadingCircle
                property: "rotation"
                from: 0
                to: 360
                easing.type: Easing.OutSine
                duration: 800
            }
            PauseAnimation { duration: 200 }
        }
    }

    // Keep actionable playback diagnostics; only replace the connecting text.
    Text {
        anchors.centerIn: parent
        width: parent.width - 20
        text: stream.error
        color: "#cccccc"
        font.pixelSize: 20
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        visible: stream.active && !stream.playing && stream.error !== ""
    }
}
