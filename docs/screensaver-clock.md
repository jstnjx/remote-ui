# Screensaver clock and main UI recovery

The charging screen provides an analog or digital clock, selectable under **Settings → Display & Brightness → Digital screensaver clock**.

- **Off (default):** existing analog clock with hands and hour marks
- **On:** digital time, date and seconds on the existing black charging overlay
- Respects the already configured 12-/24-hour preference
- Retains charging indicator, dismiss gestures, power-button handling and timeout behavior
- Saved locally under `ui/digitalScreensaverClock` in the existing UI settings file

## Black main screen diagnostics

The main QML loader formerly had no `Loader.Error` presentation. A failed `MainContainer.qml` or `NoPage.qml` import could leave a black screen, while the long-press power popup remained operational.

The loader now reports the offending source in the UI log and shows an error panel with **Retry interface** when its status becomes `Loader.Error`. The error panel does not interfere with a correctly loaded UI.

The symptom can also result from unrelated runtime, brightness, or activity-screen errors; a fallback screen is **not proof** of the original failure's cause. To restore a working device, reinstall a known-good RTSP UI install archive using the Core API endpoint. Collect runtime logs to identify the exact QML component before attributing the root cause.
