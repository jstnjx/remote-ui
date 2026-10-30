// GPL-3.0-or-later.
import QtQuick 2.15

Rectangle {
    id: tile
    color: "black"
    radius: 6
    clip: true
    property var widget: ({ id: '', mode: 'hls', name: '' })
    property string baseUrl: ""
    property string viewToken: ""
    property bool active: false
    property bool nativeVideoFailed: false
    readonly property string query: "?view_token=" + encodeURIComponent(viewToken)
    readonly property string streamUrl: baseUrl + "/hls/" + widget.id + "/index.m3u8" + query
    readonly property string jpegUrl: baseUrl + "/snapshot/" + widget.id + ".jpg" + query
    readonly property bool useFrames: widget.mode === "mjpeg" || nativeVideoFailed

    Loader {
        id: player
        anchors.fill: parent
        active: tile.active
        source: tile.useFrames
            ? "qrc:/components/entities/activity/deviceclass/RtspSnapshotPlayer.qml"
            : "qrc:/components/entities/activity/deviceclass/RtspVideoPlayer.qml"
        onLoaded: {
            item.playbackUrl = tile.useFrames ? tile.jpegUrl : tile.streamUrl;
            if (!tile.useFrames) {
                item.playbackFailed.connect(function() {
                    console.warn("RTSP: native HLS unavailable, using JPEG fallback (lower frame rate)");
                    tile.nativeVideoFailed = true;
                });
            }
        }
        onStatusChanged: if (status === Loader.Error && !tile.nativeVideoFailed) tile.nativeVideoFailed = true
    }
    Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 7 }
        text: widget.name
        font.pixelSize: 14
        color: "white"
        elide: Text.ElideRight
        style: Text.Outline
        styleColor: "black"
        visible: player.status !== Loader.Ready
    }
}
