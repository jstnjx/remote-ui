#!/usr/bin/env bash
# Download verified Qt 5.15.19 source for native Remote 3 WebEngine work.
# Never modifies the vendor SDK or the firmware.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${1:-$ROOT/.qt-webengine-work}"
ARCHIVE="$DEST/qt-everywhere-opensource-src-5.15.19.tar.xz"
URL="https://download.qt.io/archive/qt/5.15/5.15.19/single/qt-everywhere-opensource-src-5.15.19.tar.xz"
SHA256="173c2326dae138bbb0d98921e9d911e55c00163d93a6db29f294b5e19ff306ae"

command -v curl >/dev/null || { echo "curl required" >&2; exit 1; }
command -v shasum >/dev/null || { echo "shasum required (macOS provides it)" >&2; exit 1; }
mkdir -p "$DEST"

if [[ ! -f "$ARCHIVE" ]]; then
    echo "Downloading official Qt 5.15.19 source (~634 MiB) ..."
    curl --fail --location --retry 3 --continue-at - --output "$ARCHIVE" "$URL"
fi
echo "$SHA256  $ARCHIVE" | shasum -a 256 -c -

if [[ ! -d "$DEST/qt-everywhere-src-5.15.19" ]]; then
    mkdir -p "$DEST/qt-everywhere-src-5.15.19"
    tar -xJf "$ARCHIVE" -C "$DEST/qt-everywhere-src-5.15.19" --strip-components=1
fi
for module in qtbase qtdeclarative qtwebengine; do
    if [[ ! -d "$DEST/qt-everywhere-src-5.15.19/$module" ]]; then
        echo "ERROR: Missing expected source module $module" >&2
        exit 1
    fi
done
echo "Verified source ready in $DEST/qt-everywhere-src-5.15.19"
echo "Not built yet. Shared Qt + Chromium cross-compilation and firmware compatibility remain unverified."
