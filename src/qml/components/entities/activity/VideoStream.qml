// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import QtQuick.Controls 2.15
import Rtsp 1.0
import Config 1.0

Rectangle {
    id: widget
    color: "black"
    radius: 12
    clip: true

    property string streamUrl: ""
    property bool streamActive: false
    onStreamActiveChanged: if (!streamActive) fullscreenPopup.close()

    RtspStream {
        id: stream
        anchors.fill: parent
        source: widget.streamUrl
        frameRate: Config.rtspFrameRate
        resolution: Config.rtspResolution
        autoQuality: Config.rtspAutoQuality
        active: widget.streamActive && widget.visible && !fullscreenPopup.opened
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

    Text {
        anchors { left: parent.left; bottom: parent.bottom; margins: 5 }
        visible: Config.rtspShowStats && stream.active
        color: colors.offwhite
        font.pixelSize: 13
        text: stream.actualFps.toFixed(1) + " FPS · " +
              (stream.cpuPercent < 0 ? "CPU N/A" : stream.cpuPercent.toFixed(0) + "% CPU") +
              " · " + stream.effectiveWidth + "×" + stream.effectiveHeight
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (widget.streamActive) fullscreenPopup.open()
    }

    Popup {
        id: fullscreenPopup
        parent: Overlay.overlay
        width: parent.width
        height: parent.height
        x: 0
        y: 0
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape
        background: Rectangle { color: "black" }

        contentItem: Item {
            RtspStream {
                id: fullscreenStream
                anchors.fill: parent
                source: widget.streamUrl
                frameRate: Config.rtspFrameRate
                resolution: Config.rtspResolution
                autoQuality: Config.rtspAutoQuality
                active: fullscreenPopup.opened && widget.streamActive
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: colors.offwhite
                text: fullscreenStream.error !== "" ? fullscreenStream.error : qsTr("Connecting…")
                visible: !fullscreenStream.playing
            }

            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 12 }
                width: 68
                height: 68
                radius: width / 2
                color: "#88000000"
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 42
                    color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: fullscreenPopup.close()
                }
            }

            Text {
                anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                visible: Config.rtspShowStats
                color: colors.offwhite
                font.pixelSize: 18
                text: fullscreenStream.actualFps.toFixed(1) + " FPS · " +
                      (fullscreenStream.cpuPercent < 0 ? "CPU N/A" :
                       fullscreenStream.cpuPercent.toFixed(0) + "% CPU") +
                      " · " + fullscreenStream.effectiveWidth + "×" + fullscreenStream.effectiveHeight
            }
        }
    }
}
