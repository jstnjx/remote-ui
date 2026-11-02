# Purpose-built Activity UI widgets

The following widgets reuse the Remote UI's native palette, icon font, tactile controls and Core-API entity methods. They are created from ordinary **Text widgets** in the Web Configurator, so neither firmware nor a new Web Configurator API schema is necessary.

| Text value | Widget | Recommended grid size |
| --- | --- | --- |
| `LIGHT` or `LIGHT;living` | Native light controls directly within the Activity widget | 2×2 or larger |
| `CLIMATE` or `CLIMATE;living` | Inline temperature tumbler, target and HVAC mode | 2×2 or larger |
| `COVER` or `COVER;shade` | Inline cover position and native open/stop/close controls | 2×2 or larger |

Selectors match a full entity ID, the final entity ID segment or a unique prefix of its final segment, case-insensitively. The Text widget's existing command entity can also provide the target; without one, the widget tries the activity's included entities, then an automatically selected target **only if exactly one** entity of the expected type is configured. Ambiguous selectors display an error rather than controlling the wrong device. Use a full ID (for example from a UI page API PATCH) if shorter suffixes conflict.

## Inline native controls: Light, Climate and Cover

The **LIGHT**, **CLIMATE** and **COVER** widgets now contain working controls **within the Activity UI itself**. They do **not** open the separate entity detail overlay; tapping, dragging and changing settings operate inside the configured grid cell.

- **Light:** loads the **original native** `OnOff.qml`, `Brightness.qml` and `Color.qml` feature pages with their native appearance, commands and behavior. The original Light controls gain an opt-in `compact` layout so brightness and color-temperature sliders fit a 2×2 cell without changing the full-screen entity. Color-enabled lights get inline Brightness and Color tabs; the icon in the header toggles power.
- **Climate:** an inline version of the entity detail's actual **Qt Controls temperature Tumbler** with a live target-temperature model, current-unit formatting, plus/minus stepping, and an inline HVAC mode control using the same native `setTargetTemperature()`, `setHvacMode()` and `turnOff()` APIs. Unsupported options cannot be selected.
- **Cover:** reuses the **native `components/entities/cover/OpenClose.qml`** controls directly for binary covers, opting into its compact sizing. Position-capable covers get the same native position value and position setter, a proportional position slider, and supported Open/Stop/Close actions. A cover that has not reported its position does not show a misleading 0%.

Native Light, Climate and Cover entity detail screens still work independently and retain their original full-screen dimensions and appearance. The inline surfaces share their entity state and command APIs; no new integration commands are introduced.

## Swipe ownership and Activity page navigation

The Activity page uses a horizontal `PathView` for page swiping. Light/Climate/Cover cards use a **passive Qt `PointHandler`** to observe touches without intercepting the native sliders, color picker or temperature Tumbler. **While a card touch is active, Activity page swiping is disabled**; it resumes on release, cancellation, widget destruction or activity closure. This prevents horizontal control gestures from accidentally switching Activity pages.

Only gestures beginning **outside** an interactive widget navigate between Activity pages. The Media Browser retains its existing internal `PathView` behavior and is not changed.

## Background styling

Light, Climate and Cover cards use a **transparent outer surface** with no gray rounded card background. The Activity page background remains visible behind each widget. Interactive native controls retain their individual contrast and active-state fills.

## Layout and performance

Each widget lives in its configured activity grid cell, uses native `colors`, `fonts`, `Components.Icon`, `Components.HapticMouseArea`, and `ui.cornerRadiusSmall`, and reads live entity state. Interaction is blocked when its activity page is not visible, the activity is off or the device is unavailable. The embedded controls reuse native UI components and their existing commands without opening a popup.

No arbitrary Home Assistant service calls, webhooks, credentials or external processing services are introduced. All control commands use the existing connected Remote Core API.

## Testing

Run `python test/ui/activity_entity_cards_sanity.py` and the repository's Code Guidelines CI. Test on the Remote or simulator at 480×800 / 480×850 with 2×2 and larger widget sizes, and with entities both available and unavailable. Verify that brightness, color, target temperature, HVAC mode, cover position and Open/Close/Stop respond **directly inside each card**, and that swiping on a widget does not switch Activity pages. Verify that swipes **outside** widgets still navigate normally. Thermostat mode support and cover position semantics are integration-dependent and require testing against the target device.
