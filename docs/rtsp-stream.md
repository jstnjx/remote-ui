# RTSP video widget (remote-ui only)

The custom UI renders an RTSP stream inside an existing **Text** widget on an activity page. It uses no new Core-API widget type, integration or external streaming server. The **remote itself** runs a local FFmpeg process and renders its decoded frames in Qt Quick.

## Add a video stream

1. Open the Remote's Web Configurator and edit an activity's UI page.
2. Add a **Text** widget and set its text to the complete URL, for example `rtsp://192.168.1.50:554/stream1`.
3. Set its size to a video-friendly area, for example a 4-column by 3-row tile on the default 4×6 grid, and save.
4. Open that activity on the remote. The URL is replaced by the live video. Ordinary text and icon widgets behave unchanged.

URLs are recognized only when the Text widget's text starts with `rtsp://` (case-insensitive, ignoring surrounding whitespace). Authentication may be embedded as `rtsp://username:password@host:554/path`; be aware that widget text is stored in the activity configuration as **plain text**, so use a camera account with restricted permissions. Escape special characters in credentials according to URL encoding rules.

## Configure frame rate

On the remote, open **Settings → User interface → RTSP stream frame rate**.
Choose **5, 10, 15, 20, 25, or 30 FPS**. The default is **10 FPS**.

The selection is saved locally via the existing UI settings store and applies
to all RTSP video widgets. If a stream is already playing, FFmpeg restarts
automatically with the selected frame rate; no activity or remote restart is
needed. Higher frame rates consume more CPU and battery, so use a low-resolution
H.264 camera substream for smoother playback.

## Resolution, fullscreen and diagnostics

The **Settings → User interface** page provides:

- **RTSP resolution:** 320×180 (default), 480×270 or 640×360.
- **RTSP stream frame rate:** 5–30 FPS in increments of five.
- **Automatically reduce RTSP quality:** on by default; when the Linux FFmpeg process uses more than 80% of one CPU core for three consecutive one-second samples, the decoder drops one output-resolution level (640×360 → 480×270 → 320×180). It does not automatically raise the resolution again during an uninterrupted session.
- **Show RTSP stream statistics:** optional overlay showing actual rendered FPS, FFmpeg CPU as a percentage of one core, and effective output dimensions. CPU metrics are available on Linux from `/proc/PID/stat`; other platforms display CPU N/A.

Tap a video tile to open a fullscreen view. The embedded decoder pauses while the fullscreen decoder is active, avoiding two concurrent decoders of the same stream. Closing fullscreen restores the embedded stream. Leaving the activity closes fullscreen and stops playback.

Higher output resolution does **not** change the RTSP camera source resolution: use a low-resolution H.264 substream whenever possible. The auto-quality response is based on FFmpeg CPU time, not the full remote system CPU load, and only reduces output scaling; a camera that sends high-bitrate 4K input will still require decoding of that input.

## Runtime requirements

- **Install the `UCR2-RTSP-install` archive**, not the basic `UCR2-static` build. It includes a static ARM64 `bin/ffmpeg` executable next to `bin/remote-ui`, with an upstream SHA-256 checksum verified during packaging. No external streaming server, additional firmware service or GStreamer is required. Installing only the UI binary produces the message "FFmpeg is not installed on the remote".
- RTSP is read directly from the camera over TCP and decoded locally. No other host or RTSP relay is required.
- The component uses FFmpeg's rawvideo output and Qt's RGB565 painted item. It does not require GStreamer or FFmpeg *development* libraries at build time.
- It requests 320×180 without audio, at the configured frame rate (10 FPS by default). **Use an H.264 low-resolution camera substream** when possible. Decoding a high-resolution source still uses CPU even though output is downscaled.
- Playback starts only when the activity detail is open on the visible page, the activity is not Off, and power mode is Normal. It stops on page switch, activity close/off, or power-mode change. Network loss triggers a retry after 3 seconds; a 12-second video stall restarts FFmpeg.
- Connection, authorization, path, timeout, and decoder failures are shown on the tile. A short sanitized FFmpeg diagnostic may also appear; RTSP URLs and login credentials are removed before display. Raw stderr is never logged.

## Limitations

- On-device playback cannot be verified without a real Remote Two/3. The bundled FFmpeg is statically linked for ARM64; decoding performance and runtime permissions still need to be checked on hardware.
- This is a **remote-ui-only convention** layered on top of the stock Text widget. The stock Web Configurator will still call it Text and may preview the URL as text. A native `video_stream` configuration type would require changes outside remote-ui.
- The video is decoded in software unless the installed FFmpeg binary transparently supports hardware acceleration. Avoid multiple simultaneous streams and monitor CPU/battery usage.

## Building

The GitHub Actions **Build & Release** workflow publishes an install-ready `*UCR2-RTSP-install*.tar.gz` file to the [Development Build](https://github.com/jstnjx/remote-ui/releases/tag/latest). **Upload that archive directly** using the Remote's Core API. Do not repack the basic UCR2 static build:

```bash
curl -fSL -u web-configurator \
  -F "file=@remote-ui-RTSP-install.tar.gz" \
  "http://REMOTE-IP/api/system/install/ui?void_warranty=yes"
```

Replace the example filename with the downloaded UCR2-RTSP-install archive. Review the [custom UI installation/warranty notes](cross-compile.md) first.

To compile and package it yourself:

```bash
make ucr2
bash tools/package-rtsp-ui.sh binaries/linux-arm64/release/remote-ui remote-ui-rtsp-install.tar.gz
```

The packaging script downloads [Shaka's pinned static ARM64 FFmpeg](https://github.com/shaka-project/static-ffmpeg-binaries/releases/tag/n8.1.2-1), verifies its SHA-256, sets executable permissions, and packages it as `bin/ffmpeg`. It also includes build and license information under `data/ffmpeg-source.txt`.

FFmpeg does not need to be downloaded by the Remote at runtime. The decoder and UI run entirely on the device.

## Connection troubleshooting

The player uses RTSP-over-TCP and FFmpeg's RTSP-specific `-timeout 5000000` (5 seconds). The earlier `-rw_timeout` option is not reliably supported with RTSP. If the stream still stops, the tile now reports a more specific reason (authentication, bad path, network, unsupported codec, or sanitized FFmpeg stderr).

Test the same RTSP URL on a computer in the same network using VLC/ffplay, preferably with an H.264 low-resolution substream. If that works but the remote says `Connection timed out`, verify the remote can reach the camera over Wi-Fi. Do not post URLs containing passwords in bug reports.
