# Home Assistant Lovelace — on-device Qt WebEngine (Option A)

## Status

This branch has a native `QtWebEngine 1.10` QML dashboard viewer, a persistent
browser profile, native touch interaction, and a **separate build mode** for
shared-Qt WebEngine. The old external screenshot/HTTP input path is no longer
used by the dashboard UI.

**It is not yet a deployable Remote 3 WebEngine package.** The official
`unfoldedcircle/r2-toolchain-qt-5.15.19-static` image builds a static Qt UI;
Qt WebEngine 5.15 does not support static builds. `make ucr2` can still compile
the UI but cannot turn on Qt WebEngine.

Do not install a binary expecting native Lovelace until a compatible target
ARM64 *shared* Qt 5.15 + Qt WebEngine runtime is obtained and tested.

## What the runtime needs

- Qt 5.15.19 **shared** aarch64 libraries built with the target's graphics
  platform / EGL/GLES options and compatible with the firmware's glibc.
- `libQt5WebEngineCore.so.5`, `libQt5WebEngine.so.5` and the dependent Qt and
  non-Qt shared libraries (NSS, ICU, fontconfig, dbus, graphics and more).
- A matching QML `QtWebEngine` module under `qml/QtWebEngine/`.
- Platform plugins (e.g. the same EGLFS platform as the installed UI),
  Qt Quick Controls and the Virtual Keyboard module built against that Qt.
- Matching ARM64 `QtWebEngineProcess`, Chromium `.pak` resources, `icudtl.dat`,
  and any required locale / translations files.
- Writable browser profile directory so Home Assistant authentication persists.
- A verified Chromium sandbox strategy appropriate for this firmware and its
  service account. Never silently turn off the sandbox as a default.

The UI and all runtime files must be packaged in permitted custom UI archive
directories (`bin/`, `data/`, `config/`). A package that merely contains
the UI executable is **not sufficient**.

## Building

Build the shared-Qt WebEngine ARM64 toolchain separately. The branch does not
provide a ready-made image or a validated firmware sysroot.

If you already have a toolchain container with `qmake`, `make`, the ARM64
cross-compiler and a matching installed shared Qt 5.15 WebEngine:

```sh
DOCKER_DEFAULT_PLATFORM=linux/amd64 \
  make ucr2-webengine WEBENGINE_TOOLCHAIN_IMAGE=<your-shared-qt-webengine-arm64-image>
```

This target executes `tools/lovelace-webengine/preflight.sh` **inside** the
toolchain, runs `qmake CONFIG+=release CONFIG+=lovelace_webengine`, and expects
a target ARM64 binary at
`binaries/linux-arm64/webengine/remote-ui`.

The preflight fails if shared Qt or the QtWebEngine ARM64 library / QML plugin is
missing. It does not prove the device's kernel, GPU, sandbox and library versions
can execute Chromium.

**Do not use `make ucr2` to test the local browser.** That target remains the
existing static build and will show a clear browser-unavailable message.

## Deployment and device preflight

Before packaging, verify:
1. The `remote-ui` and `QtWebEngineProcess` ELF machine is AArch64.
2. All `DT_NEEDED` libraries resolve to the device or bundled shared libraries.
3. The QtWebEngine QML import and its plugins use the *same* Qt ABI as the UI.
4. `QtWebEngineProcess` and Chromium resources are installed where the
   matching QtWebEngineCore expects them (or explicitly configured with
   `QTWEBENGINEPROCESS_PATH` and `QTWEBENGINE_RESOURCES_PATH`).
5. The remote's windowing stack supports Qt WebEngine's graphics context.
6. Chromium launches under the same privileges / restrictions used by the
   remote-ui service, without disabling sandboxing globally.
7. Persistent storage and cookies survive a Remote UI restart.

A different Linux distro's ARM64 Qt packages cannot be presumed compatible.
Do **not** ship the build until the runtime preflight and a minimal browser test
have succeeded on the actual device.

## Runtime behavior

Use Settings → Home Assistant dashboards. Enter a Home Assistant URL such as
`http://10.1.1.51:8123/lovelace/remote3?kiosk`. There is no renderer address.
Opening the dashboard instantiates a native `WebEngineView`; Home Assistant's
login page appears on first use. Session cookies and local storage are intended
to persist in the browser profile. No browser frames or touch events are sent
to another computer.

## Known remaining work

- Obtain a compatible shared Qt 5.15 ARM64 target toolchain and firmware sysroot.
- Build and bundle `QtWebEngineProcess`, libraries, QML imports and data.
- Configure persistent browser profile location explicitly for UCOS.
- Test graphics backend, Chromium sandbox, memory and battery impact.
- Test the Home Assistant login, Lovelace custom cards, scrolling and keyboard
  on a real Remote 3.
- Add safe packaging/recovery once the complete device runtime is verified.

The current PR is an **implementation scaffold, not a verified firmware-ready
local browser**.
