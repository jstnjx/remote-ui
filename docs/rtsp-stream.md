# RTSP video widget (remote-ui only)

The custom UI renders an RTSP stream inside an existing **Text** widget on an activity page. It uses no new Core-API widget type, integration or external streaming server. The **remote itself** runs a local FFmpeg process and renders its decoded frames in Qt Quick.

## Add a video stream

1. Open the Remote's Web Configurator and edit an activity's UI page.
2. Add a **Text** widget and set its text to the complete URL, for example `rtsp://192.168.1.50:554/stream1`.
3. Set its size to a video-friendly area, for example a 4-column by 3-row tile on the default 4×6 grid, and save.
4. Open that activity on the remote. The URL is replaced by the live video. Ordinary text and icon widgets behave unchanged.

URLs are recognized only when the Text widget's text starts with `rtsp://` (case-insensitive, ignoring surrounding whitespace). Authentication may be embedded as `rtsp://username:password@host:554/path`; be aware that widget text is stored in the activity configuration as **plain text**, so use a camera account with restricted permissions. Escape special characters in credentials according to URL encoding rules.

## Runtime requirements

- **Install the `UCR2-RTSP-install` archive**, not the basic `UCR2-static` build. It includes a static ARM64 `bin/ffmpeg` executable next to `bin/remote-ui`, with an upstream SHA-256 checksum verified during packaging. No external streaming server, additional firmware service or GStreamer is required. Installing only the UI binary produces the message "FFmpeg is not installed on the remote".
- RTSP is read directly from the camera over TCP and decoded locally. No other host or RTSP relay is required.
- The component uses FFmpeg's rawvideo output and Qt's RGB565 painted item. It does not require GStreamer or FFmpeg *development* libraries at build time.
- It requests 320×180 at 10 fps without audio. **Use an H.264 low-resolution camera substream** when possible. Decoding a high-resolution source still uses CPU even though output is downscaled.
- Playback starts only when the activity detail is open on the visible page, the activity is not Off, and power mode is Normal. It stops on page switch, activity close/off, or power-mode change. Network loss triggers a retry after 3 seconds; a 12-second video stall restarts FFmpeg.
- The decoder error is displayed on the tile without printing the RTSP address or credentials to logs.

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
