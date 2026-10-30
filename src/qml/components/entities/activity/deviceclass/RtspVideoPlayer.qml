// GPL-3.0-or-later.
import QtQuick 2.15
import QtMultimedia 5.15

// Qt 5's Video convenience type does not implement onError. Use MediaPlayer
// (which exposes the error(error, errorString) signal) with VideoOutput.
Item {
    id: root
    property string playbackUrl: ""
    property bool reportedFailure: false
    signal playbackFailed()

    function failPlayback(reason) {
        if (reportedFailure) return;
        reportedFailure = true;
        console.warn("RTSP HLS playback failed: " + reason);
        playbackFailed();
    }

    MediaPlayer {
        id: player
        source: root.playbackUrl
        autoPlay: true
        muted: true
        volume: 0
        onError: {
            if (error !== MediaPlayer.NoError) root.failPlayback(errorString);
        }
        onStatusChanged: {
            if (status === MediaPlayer.InvalidMedia) root.failPlayback(errorString || "Invalid media");
        }
    }

    VideoOutput {
        anchors.fill: parent
        source: player
        fillMode: VideoOutput.PreserveAspectCrop
    }

    // AVFoundation may fail silently for an unsupported HLS playlist.
    // Do not keep a black player on the screen indefinitely.
    Timer {
        interval: 14000
        running: root.playbackUrl !== "" && !root.reportedFailure
        repeat: false
        onTriggered: {
            if (player.playbackState !== MediaPlayer.PlayingState) {
                root.failPlayback("no playback after startup timeout");
            }
        }
    }
}
