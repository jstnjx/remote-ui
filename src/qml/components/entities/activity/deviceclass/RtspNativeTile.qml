// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Rtsp.Native 1.0

// Device-only Video Stream widget, created by Activity.qml just like Media Player.
// RTSP is decoded within this process; no simulator MJPEG endpoint is contacted.
Rectangle {
    id: tile
    color: "black"
    radius: 6
    clip: true
    property string streamUrl: ""
    property string displayName: "Video Stream"
    property bool active: false
    property int decodeWidth: 640
    property int maxFps: 15

    RtspNativeSurface {
        anchors.fill: parent
        rtspUrl: tile.streamUrl
        decodeWidth: tile.decodeWidth
        maxFps: tile.maxFps
        active: tile.active && tile.visible && tile.streamUrl !== ""
    }
    Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 7 }
        text: tile.displayName
        font.pixelSize: 14
        color: "white"
        elide: Text.ElideRight
        style: Text.Outline
        styleColor: "black"
        visible: tile.streamUrl === ""
    }
}
