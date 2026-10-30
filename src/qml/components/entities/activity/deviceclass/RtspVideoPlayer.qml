// GPL-3.0-or-later.
import QtQuick 2.15
import QtMultimedia 5.15

Item {
    id: root
    property string playbackUrl: ""
    signal playbackFailed()
    Video {
        id: video
        anchors.fill: parent
        source: root.playbackUrl
        autoPlay: true
        muted: true
        volume: 0
        fillMode: VideoOutput.PreserveAspectCrop
        onError: if (error !== MediaPlayer.NoError) root.playbackFailed()
        onStatusChanged: if (status === MediaPlayer.InvalidMedia) root.playbackFailed()
    }
    // Some Qt 5 multimedia backends never report an explicit HLS error.
    // Fall back to JPEG frames when playback cannot start in a reasonable time.
    Timer {
        interval: 14000
        running: root.playbackUrl !== ""
        repeat: false
        onTriggered: if (video.playbackState !== MediaPlayer.PlayingState) root.playbackFailed()
    }
}
