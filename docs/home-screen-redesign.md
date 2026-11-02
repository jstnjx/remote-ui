# Optional redesigned home screen

The redesigned home is an **opt-in** skin for the first configured home page. Enable it under **Settings → Home screen → Use redesigned home screen**. When disabled, the untouched original `Page.qml` home is shown immediately. Restricted profiles retain the stock screen. The original page is still loaded underneath, so a QML Loader failure also falls back to the stock view.

## Layout and entity model

The reference layout follows the 480×850/480×800 Remote display aspect ratio:

- A slim, black top bar shows the **configured page name**, battery level/percentage and Settings. There is **no clock in the top bar**.
- A single large time and smaller date appear in the hero area, using the existing 12/24-hour clock preference and the current page's **configured background image**, darkened with a black fade.
- An optional 100px-high media card displays the artwork on the left and current media title/artist on the right. It appears only when the page has an active activity/media player to associate with a media source; the player detail view opens on tap. No embedded transport controls.
- Below the header, the **current page's existing `PageItemList`** provides a single scrollable column. Its saved ordering, entity IDs and groups are retained exactly. This is **not** the global activities list, and no unconfigured placeholders, Activities/Rooms switch or Quick Scenes are displayed.
- Rows are large, square-edged dark surfaces with the same native entity icon/name/status/availability presentation and commands as the stock screen. The final small chevron indicates that touching a row opens the entity detail; native group rows still expand to reveal their configured entities.
- The media card and row corners are square. Default-page entities and groups keep their original corner radius, dimensions and behavior when the redesign is off.

The native `src/qml/components/entities/Base.qml` and `src/qml/components/group/Base.qml` provide tap, long-press, disabled/loading, controls, selection, and group behavior. Only a `redesignedHomeStyle` flag changes their row appearance. Core API entities, groups and activity commands are unchanged.

## Input, scrolling and fallback

- Touch a row to open the same entity/group behavior as the original home. Long-press editing is unchanged.
- D-pad **Up/Down** traverses the native list and configured members of an expanded group; **Left/Right** switches pages. OK and long-press OK follow the original native button-inversion setting. HOME returns selection and scrolling to the beginning; long HOME opens the original page-edit menu.
- When the list is taller than the available viewport, it scrolls below the media area without overlapping the header. The original app status bar and bottom gradient hide while the optional screen is active, avoiding duplicate UI.
- No `ucOS`, firmware, Web Configurator or Core API schema changes are needed.

## Recovery and testing

If needed, return to **Settings → Home screen** and disable the redesigned-home option. The saved page configuration and original UI are preserved. `test/ui/home_layout_sanity.py` checks the configured page data source, reference-style geometry, media/header and keypad behavior across 480×850, 480×800 and smaller viewports.

The continuous-integration Qt build cannot establish visual correctness on real Remote hardware; confirm artwork cropping, row touch areas, group expansion and scrolling on the Remote or its simulator.
