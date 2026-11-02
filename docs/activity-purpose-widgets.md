# Purpose-built Activity UI widgets

The following widgets reuse the Remote UI's native palette, icon font, tactile controls and Core-API entity methods. They are created from ordinary **Text widgets** in the Web Configurator, so neither firmware nor a new Web Configurator API schema is necessary.

| Text value | Widget | Recommended grid size |
| --- | --- | --- |
| `LIGHT` or `LIGHT;living` | Live light status; tap for the **native Light detail overlay** | 2×2 |
| `CLIMATE` or `CLIMATE;living` | Live current/target temperatures; tap for the **native Climate overlay** | 2×2 |
| `COVER` or `COVER;shade` | Current cover state/position; tap for the **native Cover overlay** | 2×2 |
| `TP` or `TP;apple_tv` | Swipe touchpad with tap-to-select | 2×2 |
| `TOUCHPAD;apple_tv` | Long-form touchpad marker | 2×2 |

Selectors match a full entity ID, the final entity ID segment or a unique prefix of its final segment, case-insensitively. The Text widget's existing command entity can also provide the target; without one, the widget tries the activity's included entities, then an automatically selected target **only if exactly one** entity of the expected type is configured. Ambiguous selectors display an error rather than controlling the wrong device. Use a full ID (for example from a UI page API PATCH) if shorter suffixes conflict.

## Inline native controls: Light, Climate and Cover

The **LIGHT**, **CLIMATE** and **COVER** widgets now contain working controls **within the Activity UI itself**. They do **not** open the separate entity detail overlay; tapping, dragging and changing settings operate inside the configured grid cell.

- **Light:** loads the **original native** `OnOff.qml`, `Brightness.qml` and `Color.qml` feature pages with their native appearance, commands and behavior. The original Light controls gain an opt-in `compact` layout so brightness and color-temperature sliders fit a 2×2 cell without changing the full-screen entity. Color-enabled lights get inline Brightness and Color tabs; the icon in the header toggles power.
- **Climate:** an inline version of the entity detail's actual **Qt Controls temperature Tumbler** with a live target-temperature model, current-unit formatting, plus/minus stepping, and an inline HVAC mode control using the same native `setTargetTemperature()`, `setHvacMode()` and `turnOff()` APIs. Unsupported options cannot be selected.
- **Cover:** reuses the **native `components/entities/cover/OpenClose.qml`** controls directly for binary covers, opting into its compact sizing. Position-capable covers get the same native position value and position setter, a proportional position slider, and supported Open/Stop/Close actions. A cover that has not reported its position does not show a misleading 0%.

Native Light, Climate and Cover entity detail screens still work independently and retain their original full-screen dimensions and appearance. The inline surfaces share their entity state and command APIs; no new integration commands are introduced.

## Touchpad

A gesture surface rather than a directional-button grid:

- Swipe up/down/left/right → one directional command on release, after a 26px movement threshold.
- Tap anywhere → select/OK.
- Press and hold without moving → use the selected Remote's mapped `DPAD_MIDDLE` long-press action, if configured.

The touchpad first looks up the existing Remote entity `buttonMapping` entry for `DPAD_UP`, `DPAD_DOWN`, `DPAD_LEFT`, `DPAD_RIGHT` or `DPAD_MIDDLE`, and dispatches that mapping's `short_press` or `long_press` command/parameters exactly. This means the touchpad can reuse native integration-defined buttons, including device-specific mappings.

For Remote entities with no matching mapping, the widget falls back to `remote.send_cmd` (or `remote.send` if supported). For Home Assistant Remote entities it uses lowercase `up`, `down`, `left`, `right`, `select`; other integrations receive uppercase directions and `OK`. **Fallback command vocabularies are integration-specific**, so confirm they are supported or supply a native button mapping. It does not guess at long-press commands. Gesture commands are disabled when the activity is inactive or the entity unavailable.

## Swipe ownership and Activity page navigation

The Activity page uses a horizontal `PathView` for page swiping. A Light/Climate/Cover card now uses a **passive Qt `PointHandler`** to observe a touch anywhere on the widget without intercepting gestures on the native sliders, color picker or temperature Tumbler. The Touchpad continues to use a full-surface `MouseArea` with `preventStealing`. **While a widget touch is active, Activity page swiping is disabled** using the same shared gesture count; it is restored on release, cancellation, widget destruction or activity closure. This prevents a horizontal slider or touchpad gesture from accidentally flipping to the next page.

Only gestures beginning **outside** an interactive widget navigate between Activity pages. The Media Browser retains its existing internal `PathView` behavior and is not changed.

## Layout and performance

Each widget lives in its configured activity grid cell, uses native `colors`, `fonts`, `Components.Icon`, `Components.HapticMouseArea`, and `ui.cornerRadiusSmall`, and reads live entity state. Interaction is blocked when its activity page is not visible, the activity is off or the device is unavailable. The embedded controls reuse native UI components and their existing commands without opening a popup.

No arbitrary Home Assistant service calls, webhooks, credentials or external processing services are introduced. All control commands use the existing connected Remote Core API.

## Testing

Run `python test/ui/activity_cards_touchpad_sanity.py` and the repository's Code Guidelines CI. Test on the Remote or simulator at 480×800 / 480×850 with 2×2 and larger widget sizes, and with entities both available and unavailable. Verify that brightness, color, target temperature, HVAC mode, cover position and Open/Close/Stop respond **directly inside each card**, and that swiping on a widget does not switch Activity pages. Verify that swipes **outside** widgets still navigate normally. Real touchpad command vocabulary, thermostat mode support and cover position semantics are integration-dependent and require testing against the target device.
