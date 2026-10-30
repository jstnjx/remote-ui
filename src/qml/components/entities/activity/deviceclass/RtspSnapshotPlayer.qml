// GPL-3.0-or-later.
import QtQuick 2.15

Image {
    id: image
    property string playbackUrl: ""
    cache: false
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    Timer {
        interval: 250
        repeat: true
        running: image.visible && image.playbackUrl !== ""
        triggeredOnStart: true
        onTriggered: image.source = image.playbackUrl + "&frame=" + Date.now()
    }
}
