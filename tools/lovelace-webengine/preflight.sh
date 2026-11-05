#!/usr/bin/env bash
# Verify that this environment can build the local Qt WebEngine frontend.
# Run inside the target ARM64 shared-Qt toolchain, not the static UC image.
set -euo pipefail

QMAKE="${QMAKE:-qmake}"
command -v "$QMAKE" >/dev/null || { echo "ERROR: qmake not found" >&2; exit 1; }
command -v readelf >/dev/null || { echo "ERROR: readelf not found" >&2; exit 1; }

QT_VERSION="$("$QMAKE" -query QT_VERSION)"
QT_LIBS="$("$QMAKE" -query QT_INSTALL_LIBS)"
QT_BINS="$("$QMAKE" -query QT_INSTALL_BINS)"
QT_PLUGINS="$("$QMAKE" -query QT_INSTALL_PLUGINS)"
QT_IMPORTS="$("$QMAKE" -query QT_INSTALL_QML 2>/dev/null || true)"

echo "Qt version:    $QT_VERSION"
echo "Qt libraries:  $QT_LIBS"
echo "Qt executables:$QT_BINS"
echo "Qt QML:        $QT_IMPORTS"

[[ "$QT_VERSION" == 5.15.* ]] || { echo "ERROR: Qt 5.15 is required" >&2; exit 1; }
[[ -e "$QT_LIBS/libQt5Core.so" || -e "$QT_LIBS/libQt5Core.so.5" ]] || {
    echo "ERROR: Qt is static or lacks shared QtCore. WebEngine cannot use static Qt." >&2; exit 1;
}
[[ -e "$QT_LIBS/libQt5WebEngineCore.so" || -e "$QT_LIBS/libQt5WebEngineCore.so.5" ]] || {
    echo "ERROR: Missing shared QtWebEngineCore" >&2; exit 1;
}
[[ -e "$QT_LIBS/libQt5WebEngine.so" || -e "$QT_LIBS/libQt5WebEngine.so.5" ]] || {
    echo "ERROR: Missing shared QtWebEngine" >&2; exit 1;
}
[[ -n "$QT_IMPORTS" && -d "$QT_IMPORTS/QtWebEngine" ]] || {
    echo "ERROR: Missing QtWebEngine QML plugin directory" >&2; exit 1;
}
QT_LIB="$(find -L "$QT_LIBS" -maxdepth 1 -name 'libQt5WebEngineCore.so*' -type f | head -n 1)"
[[ -n "$QT_LIB" ]] || { echo "ERROR: No readable Qt WebEngine shared ELF library" >&2; exit 1; }
readelf -h "$QT_LIB" | grep -q 'AArch64' || {
    echo "ERROR: WebEngine library is not AArch64" >&2; exit 1;
}
echo "PASS: Shared ARM64 Qt WebEngine detected."
echo "NOTE: This does not prove compatibility with Remote firmware GPU, glibc or system libraries."
