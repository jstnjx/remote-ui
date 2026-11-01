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

    Text {
        anchors.centerIn: parent
        width: parent.width - 20
        text: stream.error !== "" ? stream.error : "Connecting to RTSP stream..."
        color: "#cccccc"
        font.pixelSize: 20
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        visible: stream.active && !stream.playing
    }
}
