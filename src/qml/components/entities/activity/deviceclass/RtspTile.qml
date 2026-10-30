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
    // The native simulator uses one persistent JPEG stream regardless of
    // the browser editor's HLS/MJPEG delivery setting.
    readonly property string streamUrl: baseUrl + "/mjpeg/" + widget.id

    Loader {
        id: player
        anchors.fill: parent
        active: tile.active
        source: "qrc:/components/entities/activity/deviceclass/RtspVideoPlayer.qml"
        onLoaded: {
            item.playbackUrl = tile.streamUrl;
            item.playbackToken = tile.viewToken;
        }
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
