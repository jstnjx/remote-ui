// GPL-3.0-or-later.
import QtQuick 2.15

// JPEG fallback for Qt Multimedia installations without working native HLS.
// Keep a single image in memory and never queue another HTTP load while the
// preceding request is outstanding. The sidecar shares a video decoder.
Image {
    id: image
    property string playbackUrl: ""
    cache: false
    asynchronous: true
    fillMode: Image.PreserveAspectCrop

    Timer {
        interval: 85  // up to ~12 fps; actual rate follows the camera/decoder
        repeat: true
        running: image.visible && image.playbackUrl !== ""
        triggeredOnStart: true
        onTriggered: {
            if (image.status !== Image.Loading) {
                image.source = image.playbackUrl + "&frame=" + Date.now();
            }
        }
    }
}
