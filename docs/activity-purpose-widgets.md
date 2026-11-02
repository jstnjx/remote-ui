# Purpose-built Activity UI widgets

The following widgets reuse the Remote UI's native palette, icon font, tactile controls and Core-API entity methods. They are created from ordinary **Text widgets** in the Web Configurator, so neither firmware nor a new Web Configurator API schema is necessary.

| Text value | Widget | Recommended grid size |
| --- | --- | --- |
| `LIGHT` or `LIGHT;living` | Light card with on/off and brightness, optionally color temperature | 2×2 or 2×3 |
| `CLIMATE` or `CLIMATE;living` | Climate card with current and target temperatures, +/− and HVAC mode | 2×2 |
| `COVER` or `COVER;shade` | Cover with open/stop/close and position when supported | 2×2 |
| `TP` or `TP;apple_tv` | Swipe touchpad with tap-to-select | 2×2 |
| `TOUCHPAD;apple_tv` | Long-form touchpad marker | 2×2 |

Selectors match a full entity ID, the final entity ID segment or a unique prefix of its final segment, case-insensitively. The Text widget's existing command entity can also provide the target; without one, the widget tries the activity's included entities, then an automatically selected target **only if exactly one** entity of the expected type is configured. Ambiguous selectors display an error rather than controlling the wrong device. Use a full ID (for example from a UI page API PATCH) if shorter suffixes conflict.

## Light card

The card reuses the native `Light` entity: icon, name, current on/off state, native `toggle()` command and `LightFeatures.Dim` brightness slider. For brightness-enabled lights, the slider operates from 0 to 255 and calls `setBrightness()` **on release**, preventing a command for every finger movement. On sufficiently tall cards, supported color-temperature lights also display a second native `setColorTemperature()` control. Unsupported features are hidden rather than displayed as broken buttons.

## Climate card

Displays the current temperature where `ClimateFeatures.Current_temperature` is available, the native target temperature and temperature-unit label, with compact plus/minus hit targets. The controls respect `targetTemperatureStep`, `minTemperature` and `maxTemperature`. Where available, the mode button cycles only through supported Off, Heat, Cool and Auto commands using `setHvacMode()` or `turnOff()`. For a range-only thermostat, the single-target buttons are disabled.

## Cover card

Shows state or known position, optional 0–100% position slider, and native Open, Stop and Close buttons. Features are gated using `CoverFeatures.Open`, `Close`, `Stop` and `Position`; the position slider is available only for covers supporting positional control. Like the full-screen cover UI, `positionAvailable` prevents an unreported position from being shown as 0%.

## Touchpad

A gesture surface rather than a directional-button grid:

- Swipe up/down/left/right → one directional command on release, after a 26px movement threshold.
- Tap anywhere → select/OK.
- Press and hold without moving → use the selected Remote's mapped `DPAD_MIDDLE` long-press action, if configured.

The touchpad first looks up the existing Remote entity `buttonMapping` entry for `DPAD_UP`, `DPAD_DOWN`, `DPAD_LEFT`, `DPAD_RIGHT` or `DPAD_MIDDLE`, and dispatches that mapping's `short_press` or `long_press` command/parameters exactly. This means the touchpad can reuse native integration-defined buttons, including device-specific mappings.

For Remote entities with no matching mapping, the widget falls back to `remote.send_cmd` (or `remote.send` if supported). For Home Assistant Remote entities it uses lowercase `up`, `down`, `left`, `right`, `select`; other integrations receive uppercase directions and `OK`. **Fallback command vocabularies are integration-specific**, so confirm they are supported or supply a native button mapping. It does not guess at long-press commands. Gesture commands are disabled when the activity is inactive or the entity unavailable.

## Layout and performance

Each widget lives in its configured activity grid cell, uses native `colors`, `fonts`, `Components.Icon`, `Components.HapticMouseArea`, and `ui.cornerRadiusSmall`, and reads live entity state. Interaction is blocked when its activity page is not visible, the activity is off or the device does not accept commands. The cards are compact variants of the existing native entity controls, not duplications of their full-screen fixed-size slider layouts.

No arbitrary Home Assistant service calls, webhooks, credentials or external processing services are introduced. All control commands use the existing connected Remote Core API.

## Testing

Run `python test/ui/activity_cards_touchpad_sanity.py` and the repository's Code Guidelines CI. Test on the Remote or simulator at 480×800 / 480×850 with 2×2 and larger widget sizes, and with entities both available and unavailable. Real touchpad command vocabulary, thermostat mode support and cover position semantics are integration-dependent and require testing against the target device.
