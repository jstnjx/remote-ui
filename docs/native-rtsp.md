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

## Device-local configuration for development

A prototype Remote can display Video Stream widgets without a patched Core backend.
Put an owner-only JSON configuration at `$UC_CONFIG_HOME/video-streams.json`.
Alternatively, set `UC_NATIVE_RTSP_CONFIG_PATH` to an absolute path when launching
Remote UI. This is a local file **on the Remote**; there is no HTTP streaming
server, Docker requirement or device-to-proxy connection.

```json
{
  "version": 1,
  "endpoints": {
    "front-door": {
      "url": "rtsp://camera-user:camera-password@192.0.2.10:554/stream"
    }
  },
  "widgets": [
    {
      "activity_id": "uc.main.activity.example",
      "page_id": "activity-page-id",
      "endpoint_ref": "front-door",
      "name": "Front Door",
      "location": { "x": 0, "y": 0 },
      "size": { "width": 2, "height": 2 },
      "decode_width": 640,
      "max_fps": 15
    }
  ]
}
```

Use actual activity/page IDs from Core. The example address is documentation-only.
Create and install the file locally with mode `0600` (and ownership matching
the Remote UI process):

```sh
install -m 600 /secure/location/video-streams.json "$UC_CONFIG_HOME/video-streams.json"
```

Do not commit real camera credentials to Git or place them in shell command
arguments. The file is read with `O_NOFOLLOW`; it must be a regular file
owned by the Remote UI user with no group/other permissions. Invalid files
are rejected. Only the endpoint reference, display label, geometry and
decoding parameters are returned to QML. The C++ decoder resolves the URL
privately, so credentials are not serialized into page metadata.

The local file is a **temporary development adapter**, not a native Core
configuration or multi-user camera management system. Once a supported Core
backend is available, a privileged Core-to-UI endpoint resolver should
replace this file without exposing passwords through the Web Configurator.

A future compatible Core implementation must:
- Persist `video_stream` activity items with a stable `endpoint_ref`.
- Resolve the endpoint for the **authorized Remote UI process** to the privileged Remote UI C++ resolver. Neither the URL nor a password may be stored in activity-page JSON or returned to Web Configurator clients.
- Never serialize credentials to UI logs or metadata APIs.
- Invalidate active streams on page/activity changes and suspend.
- Include a migration path for existing simulator-sidecar settings.

Until that Core integration is available, stock Core cannot persist `video_stream` items; the owner-only local config enables a direct-camera physical-device prototype without changing stock Core.

## Initial codec scope

RTSP/TCP, video only, H.264 first. FFmpeg can also negotiate H.265 if included by the target SDK, but software decoding performance is not guaranteed. Rendering is capped at 15 FPS by default. Hardware acceleration, multi-camera stress tests, secure secret delivery, thermal measurements, standby behavior and device OTA packaging remain release blockers.

See [UCOS firmware workspace](https://github.com/jstnjx/ucos) for the firmware-level requirements.
