#!/usr/bin/env bash
# Copyright (c) 2026 jstnjx
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Assemble an installable Remote Two/3 UI package with an on-device FFmpeg
# executable. The upstream release and its SHA-256 checksum are pinned.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
    echo "Usage: bash tools/package-rtsp-ui.sh <arm64-remote-ui> [archive.tar.gz] [version]" >&2
    exit 2
fi

UI_BINARY="$1"
ARCHIVE="remote-ui-rtsp-install.tar.gz"
VERSION="0.1.1"
if [[ $# -ge 2 ]]; then ARCHIVE="$2"; fi
if [[ $# -ge 3 ]]; then VERSION="$3"; fi

FFMPEG_URL="https://github.com/shaka-project/static-ffmpeg-binaries/releases/download/n8.1.2-1/ffmpeg-linux-arm64"
FFMPEG_SHA256="6e7b1d7d1aa8c35e3fedd78a140aa0968717aeb7386ecfb0ee00773d9f0a4503"

if [[ ! -s "$UI_BINARY" ]]; then
    echo "Cannot find compiled Remote Two/3 ARM64 remote-ui: $UI_BINARY" >&2
    exit 1
fi
if [[ "$VERSION" == *\"* || "$VERSION" == *\\* || "$VERSION" == *$'\n'* ]]; then
    echo "Invalid version value" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/bin" "$TMP_DIR/data"
cp "$UI_BINARY" "$TMP_DIR/bin/remote-ui"
chmod 755 "$TMP_DIR/bin/remote-ui"

echo "Downloading pinned ARM64 static FFmpeg from Shaka..."
curl -fL --retry 3 --connect-timeout 30 --max-time 300 \
    -o "$TMP_DIR/bin/ffmpeg" "$FFMPEG_URL"

if command -v shasum >/dev/null 2>&1; then
    ACTUAL_SHA256="$(shasum -a 256 "$TMP_DIR/bin/ffmpeg" | cut -d' ' -f1)"
elif command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_SHA256="$(sha256sum "$TMP_DIR/bin/ffmpeg" | cut -d' ' -f1)"
else
    echo "SHA-256 tool (shasum or sha256sum) is required" >&2
    exit 1
fi
if [[ "$ACTUAL_SHA256" != "$FFMPEG_SHA256" ]]; then
    echo "FFmpeg SHA-256 mismatch: refusing to package unverified executable" >&2
    exit 1
fi

# Check the ELF machine and static linkage when readelf is present (Linux CI).
if command -v readelf >/dev/null 2>&1; then
    if ! readelf -h "$TMP_DIR/bin/ffmpeg" | grep -q "Machine:.*AArch64"; then
        echo "Downloaded FFmpeg is not an AArch64 ELF executable" >&2
        exit 1
    fi
    if readelf -l "$TMP_DIR/bin/ffmpeg" | grep -q "INTERP"; then
        echo "Downloaded FFmpeg requires a dynamic loader" >&2
        exit 1
    fi
fi
chmod 755 "$TMP_DIR/bin/ffmpeg"

cat >"$TMP_DIR/release.json" <<EOF
{
  "version": "$VERSION",
  "name": {"en": "RTSP Remote UI"},
  "description": {"en": "Custom Remote UI with on-device RTSP decoding and bundled FFmpeg"},
  "developer": {"name": "jstnjx", "url": "https://github.com/jstnjx"},
  "home_page": "https://github.com/jstnjx/remote-ui"
}
EOF

cat >"$TMP_DIR/data/ffmpeg-source.txt" <<EOF
FFmpeg is third-party GPL software. The ARM64 executable was obtained from:
$FFMPEG_URL

SHA-256: $FFMPEG_SHA256
Shaka release: n8.1.2-1
Build scripts, upstream source and licensing:
https://github.com/shaka-project/static-ffmpeg-binaries/tree/n8.1.2-1
https://ffmpeg.org/download.html
https://www.ffmpeg.org/legal.html

Remote UI sources:
https://github.com/jstnjx/remote-ui
EOF

mkdir -p "$(dirname "$ARCHIVE")"
tar -czf "$ARCHIVE" -C "$TMP_DIR" release.json bin data
for REQUIRED in release.json bin/remote-ui bin/ffmpeg data/ffmpeg-source.txt; do
    if ! tar -tzf "$ARCHIVE" | grep -Fxq "$REQUIRED"; then
        echo "Installation archive is missing $REQUIRED" >&2
        exit 1
    fi
done

echo "Created complete custom UI installation package: $ARCHIVE"
ls -lh "$ARCHIVE"
