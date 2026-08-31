// Copyright (c) 2022-2026 Unfolded Circle ApS and/or its affiliates. <hello@unfoldedcircle.com>
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 MEDIA STREAM COMPONENT

 Native Activity UI element for live video streams.
 The component owns playback and tears the player down whenever its Activity
 page is no longer active. Protocol support is provided by the platform's
 Qt Multimedia backend.
**/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia 5.15 as Multimedia

import "qrc:/components" as Components

Rectangle {
    id: mediaStream

    width: 80
    height: 80
    color: colors.black
    radius: ui.cornerRadiusSmall
    clip: true

    property url streamUrl: ""
    property bool streamMuted: true
    property bool streamAutoPlay: true
    property string streamFillMode: "fit"
    property string streamTitle: ""
    property bool streamShowTitle: true
    property bool streamShowStatus: true

    // Controlled by the Activity page renderer. Playback is stopped as soon as
    // the containing page is not current or the Activity detail is not visible.
    property bool active: true

    property bool userStarted: false

    readonly property bool hasSource: streamUrl.toString() !== ""
    readonly property bool shouldPlay: active && hasSource && (streamAutoPlay || userStarted)
    readonly property bool isPlaying: streamPlayer.playbackState === Multimedia.MediaPlayer.PlayingState
    readonly property bool hasError: streamPlayer.errorString !== ""

    function syncPlayback() {
        if (shouldPlay) {
            streamPlayer.play();
        } else {
            streamPlayer.stop();
        }
    }

    function retry() {
        if (!active || !hasSource) {
            return;
        }

        streamPlayer.stop();
        streamPlayer.source = streamUrl;
        Qt.callLater(function() {
            if (mediaStream.shouldPlay) {
                streamPlayer.play();
            }
        });
    }

    onActiveChanged: syncPlayback()
    onStreamAutoPlayChanged: syncPlayback()
    onStreamUrlChanged: {
        streamPlayer.stop();
        streamPlayer.source = streamUrl;
        userStarted = false;
        if (shouldPlay) {
            Qt.callLater(syncPlayback);
        }
    }

    Component.onCompleted: {
        streamPlayer.source = streamUrl;
        syncPlayback();
    }

    Component.onDestruction: streamPlayer.stop()

    Multimedia.MediaPlayer {
        id: streamPlayer
        autoPlay: false
        muted: mediaStream.streamMuted
    }

    Multimedia.VideoOutput {
        anchors.fill: parent
        source: streamPlayer
        fillMode: mediaStream.streamFillMode === "crop"
                  ? Multimedia.VideoOutput.PreserveAspectCrop
                  : Multimedia.VideoOutput.PreserveAspectFit
    }

    // Loading veil. Keep it deliberately lightweight so the live video remains
    // the dominant visual element and it matches other native Remote UI states.
    Rectangle {
        anchors.fill: parent
        color: colors.black
        opacity: 0.55
        visible: mediaStream.shouldPlay && !mediaStream.isPlaying && !mediaStream.hasError

        BusyIndicator {
            anchors.centerIn: parent
            running: parent.visible
            width: Math.min(64, mediaStream.width * 0.22)
            height: width
        }

        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.verticalCenter
                topMargin: 44
            }
            width: Math.max(0, parent.width - 40)
            text: qsTr("Connecting to stream…")
            color: colors.offwhite
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font: fonts.secondaryFont(20)
        }
    }

    // Empty-source state. This is a configuration problem, not a decoder error.
    Item {
        anchors.fill: parent
        visible: mediaStream.active && !mediaStream.hasSource

        Components.Icon {
            icon: "uc:triangle-exclamation"
            color: colors.light
            size: Math.min(64, mediaStream.width * 0.2)
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: noSourceText.top
                bottomMargin: 12
            }
        }

        Text {
            id: noSourceText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 32
            width: Math.max(0, parent.width - 32)
            text: qsTr("No media stream configured")
            color: colors.light
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font: fonts.secondaryFont(20)
        }
    }

    // Decoder/network errors use the Remote UI warning treatment and expose a
    // retry target without swallowing normal swipe gestures during playback.
    Rectangle {
        id: errorOverlay
        anchors.fill: parent
        color: colors.black
        opacity: 0.88
        visible: mediaStream.active && mediaStream.hasSource && mediaStream.hasError

        Components.Icon {
            id: errorIcon
            icon: "uc:triangle-exclamation"
            color: colors.red
            size: Math.min(64, mediaStream.width * 0.2)
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: errorText.top
                bottomMargin: 10
            }
        }

        Text {
            id: errorText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 16
            width: Math.max(0, parent.width - 32)
            text: streamPlayer.errorString
            color: colors.offwhite
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font: fonts.secondaryFont(19)
        }

        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: errorText.bottom
                topMargin: 8
            }
            text: qsTr("Tap to retry")
            color: colors.light
            font: fonts.secondaryFont(18)
        }

        Components.HapticMouseArea {
            anchors.fill: parent
            onClicked: mediaStream.retry()
        }
    }

    // Manual-start affordance for streams configured with autoplay disabled.
    Rectangle {
        width: 72
        height: 72
        radius: width / 2
        anchors.centerIn: parent
        color: colors.black
        opacity: 0.72
        visible: mediaStream.active && mediaStream.hasSource && !mediaStream.streamAutoPlay && !mediaStream.userStarted && !mediaStream.hasError

        Components.Icon {
            icon: "uc:play"
            color: colors.offwhite
            size: 52
            anchors.centerIn: parent
        }

        Components.HapticMouseArea {
            anchors.fill: parent
            onClicked: {
                mediaStream.userStarted = true;
                mediaStream.syncPlayback();
            }
        }
    }

    // Live-state chip is intentionally compact so it remains useful even on a
    // one-row/two-row grid item without obscuring the video.
    Rectangle {
        id: liveChip
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 8
            rightMargin: 8
        }
        width: liveText.implicitWidth + 18
        height: liveText.implicitHeight + 8
        radius: height / 2
        color: colors.black
        opacity: 0.72
        visible: mediaStream.streamShowStatus && mediaStream.isPlaying

        Row {
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: colors.red
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: liveText
                text: qsTr("LIVE")
                color: colors.offwhite
                font: fonts.secondaryFontCapitalized(14, "Bold")
            }
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: streamTitleText.visible ? streamTitleText.implicitHeight + 20 : 0
        color: colors.black
        opacity: 0.68
        visible: streamTitleText.visible
    }

    Text {
        id: streamTitleText
        anchors {
            left: parent.left
            leftMargin: 10
            right: parent.right
            rightMargin: 10
            bottom: parent.bottom
            bottomMargin: 10
        }
        text: mediaStream.streamTitle
        color: colors.offwhite
        elide: Text.ElideRight
        maximumLineCount: 1
        font: fonts.secondaryFont(20)
        visible: mediaStream.streamShowTitle && text !== ""
    }
}
