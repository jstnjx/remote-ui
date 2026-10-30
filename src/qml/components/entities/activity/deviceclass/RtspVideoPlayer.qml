// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.15
import Rtsp.Simulator 1.0

// A dedicated Qt Quick item renders actual JPEG frames from one persistent
// MJPEG HTTP response. AVFoundation live HLS can stall after its first frame.
RtspMjpegSurface {
    id: root
    property string playbackUrl: ""
    property string playbackToken: ""
    streamUrl: playbackUrl
    viewToken: playbackToken
    active: visible && playbackUrl !== "" && playbackToken !== ""
}
