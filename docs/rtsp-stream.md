# RTSP video widget (remote-ui only)

The custom UI renders an RTSP stream inside an existing **Text** widget on an activity page. It uses no new Core-API widget type, integration or external streaming server. The **remote itself** runs a local FFmpeg process and renders its decoded frames in Qt Quick.

## Add a video stream

1. Open the Remote's Web Configurator and edit an activity's UI page.
2. Add a **Text** widget and set its text to the complete URL, for example `rtsp://192.168.1.50:554/stream1`.
3. Set its size to a video-friendly area, for example a 4-column by 3-row tile on the default 4×6 grid, and save.
4. Open that activity on the remote. The URL is replaced by the live video. Ordinary text and icon widgets behave unchanged.

URLs are recognized only when the Text widget's text starts with `rtsp://` (case-insensitive, ignoring surrounding whitespace). Authentication may be embedded as `rtsp://username:password@host:554/path`; be aware that widget text is stored in the activity configuration as **plain text**, so use a camera account with restricted permissions. Escape special characters in credentials according to URL encoding rules.

## Runtime requirements

- **FFmpeg must be executable on the remote.** The player first checks the optional `UC_RTSP_FFMPEG` environment variable, then `ffmpeg` alongside the `remote-ui` executable (to support custom UI packages containing `bin/ffmpeg`), then `ffmpeg` on `PATH`. This change does **not** install FFmpeg or its runtime libraries.
- RTSP is read directly from the camera over TCP and decoded locally. No other host or RTSP relay is required.
- The component uses FFmpeg's rawvideo output and Qt's RGB565 painted item. It does not require GStreamer or FFmpeg *development* libraries at build time.
- It requests 320×180 at 10 fps without audio. **Use an H.264 low-resolution camera substream** when possible. Decoding a high-resolution source still uses CPU even though output is downscaled.
- Playback starts only when the activity detail is open on the visible page, the activity is not Off, and power mode is Normal. It stops on page switch, activity close/off, or power-mode change. Network loss triggers a retry after 3 seconds; a 12-second video stall restarts FFmpeg.
- The decoder error is displayed on the tile without printing the RTSP address or credentials to logs.

## Limitations

- On-device playback cannot be verified without a real Remote Two/3 with FFmpeg installed. If the tile says FFmpeg is not installed, the custom UI binary alone cannot decode the camera stream; package a compatible executable in `bin/ffmpeg` with its needed libraries, or use firmware that provides it.
- This is a **remote-ui-only convention** layered on top of the stock Text widget. The stock Web Configurator will still call it Text and may preview the URL as text. A native `video_stream` configuration type would require changes outside remote-ui.
- The video is decoded in software unless the installed FFmpeg binary transparently supports hardware acceleration. Avoid multiple simultaneous streams and monitor CPU/battery usage.

## Building

Build `remote-ui` using `make ucr2` and install the resulting custom UI archive as described in [cross-compile.md](cross-compile.md). This change adds no extra build-time libraries beyond Qt Quick.
