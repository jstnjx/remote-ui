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

## Native Light, Climate and Cover overlays

The Activity UI cards now display a compact **live status preview** (name, native icon, state and the most useful measurement). Tapping anywhere on a card opens the **exact same full-screen detail overlay as opening that entity from the normal Remote UI entity list**. No sliders, mode buttons or cover commands are reimplemented within the Activity card.

This uses the existing `loadThirdContainer(EntityController.screenUrl(target), {entityId, entityObj})` flow that the Activity itself already uses for included entities. Consequently, the following original features and layout are preserved automatically:

- **Light:** on/off, brightness, supported color and color-temperature controls, and the native light feature pages.
- **Climate:** native temperature tumbler and supported mode/fan popup menus.
- **Cover:** device-class-specific blind, curtain, garage or window controls, including supported position, tilt and stop actions.

The native overlay slides in on top of the current Activity. Its **X** control closes it and returns to the same Activity UI page. All original entity availability checks and feature-specific UI remain in one place: the native detail components. This prevents the compact Activity widgets from drifting away from the native design.

## Touchpad

A gesture surface rather than a directional-button grid:

- Swipe up/down/left/right → one directional command on release, after a 26px movement threshold.
- Tap anywhere → select/OK.
- Press and hold without moving → use the selected Remote's mapped `DPAD_MIDDLE` long-press action, if configured.

The touchpad first looks up the existing Remote entity `buttonMapping` entry for `DPAD_UP`, `DPAD_DOWN`, `DPAD_LEFT`, `DPAD_RIGHT` or `DPAD_MIDDLE`, and dispatches that mapping's `short_press` or `long_press` command/parameters exactly. This means the touchpad can reuse native integration-defined buttons, including device-specific mappings.

For Remote entities with no matching mapping, the widget falls back to `remote.send_cmd` (or `remote.send` if supported). For Home Assistant Remote entities it uses lowercase `up`, `down`, `left`, `right`, `select`; other integrations receive uppercase directions and `OK`. **Fallback command vocabularies are integration-specific**, so confirm they are supported or supply a native button mapping. It does not guess at long-press commands. Gesture commands are disabled when the activity is inactive or the entity unavailable.

## Swipe ownership and Activity page navigation

The Activity page uses a horizontal `PathView` for page swiping. Each native card uses a full-cell, `preventStealing` touch area. The Touchpad likewise captures its entire gesture. **As soon as a touch starts on one of these widgets, the Activity page swipe is disabled** using a shared gesture count; it is restored on release, cancellation, widget destruction or activity closure. This prevents a horizontal touchpad gesture from accidentally flipping to the next Activity UI page.

Only gestures beginning **outside** an interactive widget navigate between Activity pages. The Media Browser retains its existing internal `PathView` behavior and is not changed.

## Layout and performance

Each widget lives in its configured activity grid cell, uses native `colors`, `fonts`, `Components.Icon`, `Components.HapticMouseArea`, and `ui.cornerRadiusSmall`, and reads live entity state. Interaction is blocked when its activity page is not visible, the activity is off or the device is unavailable. Native overlays reuse the original entity commands and UI rather than making custom duplicates.

No arbitrary Home Assistant service calls, webhooks, credentials or external processing services are introduced. All control commands use the existing connected Remote Core API.

## Testing

Run `python test/ui/activity_cards_touchpad_sanity.py` and the repository's Code Guidelines CI. Test on the Remote or simulator at 480×800 / 480×850 with 2×2 and larger widget sizes, and with entities both available and unavailable. Verify the native overlay opens and closes correctly from each of the three cards, and that touches and swipes **inside** a card or Touchpad do not switch Activity pages. Verify that swipes **outside** widgets still navigate normally. Real touchpad command vocabulary, thermostat mode support and cover position semantics are integration-dependent and require testing against the target device.
