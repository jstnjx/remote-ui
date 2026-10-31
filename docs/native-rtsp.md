# Native RTSP on Remote Two/3 (development)

The device build can render a `video_stream` activity item by decoding the camera's RTSP feed **inside Remote UI** using FFmpeg's `libavformat`, `libavcodec`, `libavutil` and `libswscale`. There is no Docker container, HTTP MJPEG server, or network transcoder involved.

This code is **not a production-ready firmware release**. The stock Core backend does not accept the new item type or provide camera secrets, and the public cross-compiler image has not been verified to contain target-compatible FFmpeg libraries.

## Device build (requires an aarch64 FFmpeg SDK)

```sh
make ucr2-native-rtsp
```

This sets `UC_NATIVE_RTSP=1` inside the Docker-based toolchain. QMake includes `src/ui/native-rtsp/native-rtsp.pri`, which requires `pkg-config` entries for the target FFmpeg libraries; the build intentionally fails if the libraries are unavailable. The ordinary `make ucr2` remains unchanged.

The type `Rtsp.Native 1.0 / RtspNativeSurface` is available only in these native builds. The older MJPEG simulator overlay is disabled in this build, while remaining available for desktop development.

## Activity UI lifecycle

`Activity.qml` recognizes `video_stream` in its normal `parsePageItems` switch, creates `RtspNativeTile.qml`, positions it according to the Core grid and binds its active state to the activity/page selection. The QML item stops decoding when hidden or inactive. Video frames are decoded on a QThread and rendered by a QQuickPaintedItem.

A future compatible Core implementation must:
- Persist `video_stream` activity items with a stable `endpoint_ref`.
- Resolve the endpoint for the **authorized Remote UI process** and supply an ephemeral `resolved_rtsp_url` to this UI. The URL must not be stored in activity-page JSON or sent to Web Configurator clients.
- Never serialize credentials to UI logs or metadata APIs.
- Invalidate active streams on page/activity changes and suspend.
- Include a migration path for existing simulator-sidecar settings.

Until that Core integration is available, newly added `video_stream` widgets will not appear on physical devices running stock Core, and the native decoder has no valid source URL.

## Initial codec scope

RTSP/TCP, video only, H.264 first. FFmpeg can also negotiate H.265 if included by the target SDK, but software decoding performance is not guaranteed. Rendering is capped at 15 FPS by default. Hardware acceleration, multi-camera stress tests, secure secret delivery, thermal measurements, standby behavior and device OTA packaging remain release blockers.

See [UCOS firmware workspace](https://github.com/jstnjx/ucos) for the firmware-level requirements.
