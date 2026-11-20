# Charging screen clock

Navigate to **Settings → Display & Brightness → Digital screensaver clock**.

- **Off (default):** unchanged analog clock
- **On:** minimal digital charging display modeled on the Remote 3 product reference: mostly black background, large thin left-aligned time around the lower third, small lowercase weekday and date directly below, subtle charge symbol at the upper right, a battery percentage and slim vertical battery rail at the right edge. The rail's fill follows the actual battery level.
- Respects the existing 12/24-hour setting.
- The normal analog clock and the old bottom charging indicator are hidden when digital mode is enabled.
- The entire display still dismisses with a tap or supported remote button.
- The choice persists locally under `ui/digitalScreensaverClock` in QSettings.
