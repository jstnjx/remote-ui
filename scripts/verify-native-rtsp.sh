#!/usr/bin/env bash
# Source wiring checks only. Actual aarch64 compile and hardware tests still required.
set -euo pipefail
cd "$(dirname "$0")/.."
grep -Fq 'include($$PWD/src/ui/native-rtsp/native-rtsp.pri)' remote-ui.pro
grep -Fq 'UC_NATIVE_RTSP' src/main.cpp
grep -Fq 'ucr2-native-rtsp:' Makefile
grep -Fq 'case "video_stream"' src/qml/components/entities/activity/deviceclass/Activity.qml
grep -Fq 'Rtsp.Native 1.0' src/qml/components/entities/activity/deviceclass/RtspNativeTile.qml
grep -Fq 'src/qml/components/entities/activity/deviceclass/RtspNativeTile.qml' resources/qrc/main.qrc
grep -Fq 'libavformat' src/ui/native-rtsp/native-rtsp.pri
grep -Fq 'RtspDeviceConfig.cpp' src/ui/native-rtsp/native-rtsp.pri
grep -Fq 'endpointRef' src/qml/components/entities/activity/deviceclass/RtspNativeTile.qml
grep -Fq 'nativeRtspConfig.widgetsForPage' src/qml/components/entities/activity/deviceclass/Activity.qml
grep -Fq 'O_NOFOLLOW' src/ui/native-rtsp/RtspDeviceConfig.cpp
if grep -q 'resolved_rtsp_url' src/qml/components/entities/activity/deviceclass/Activity.qml; then
  echo 'Native activity UI must never receive raw RTSP credentials' >&2
  exit 1
fi
grep -Fq 'rtsp_transport' src/ui/native-rtsp/RtspDecodeWorker.cpp
grep -Fq 'Qt::QueuedConnection' src/ui/native-rtsp/RtspNativeSurface.cpp
grep -Fq '!nativeRtspAvailable && activityBase.state' src/qml/components/entities/activity/deviceclass/Activity.qml
if grep -E '(/mjpeg/|/hls/|RTSP_WIDGET_TOKEN|rtspWidgetUrl)' src/qml/components/entities/activity/deviceclass/RtspNativeTile.qml src/ui/native-rtsp/*.{h,cpp,pri}; then
  echo 'ERROR: native decoder must not depend on the simulator sidecar' >&2
  exit 1
fi
echo 'Native RTSP source wiring: PASS (runtime is tested separately by native-rtsp.yml)'
