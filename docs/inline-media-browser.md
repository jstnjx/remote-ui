# Inline media browser (activity UI)

Add a **Text** button/widget to an activity UI page and configure it with one of the short markers below. This avoids the stock Text widget's character limit; the real media-player entity ID stays unchanged.

| Text widget value | Target |
| --- | --- |
| `MB` | Automatically uses the media player linked to the activity |
| `MB;ps5` | Resolves an unambiguous media-player ID whose last segment starts with `ps5` |
| `MB;ps5_10_1_1_30` | Uses a longer, more specific ID suffix when multiple PS5 players are configured |
| `MB;media_player.full_id` | Full entity ID, for programmatic UI configurations with enough text space |

For example, the fixed ID `ps5_connect_driver.main.media_player.ps5_10_1_1_30` can be selected using **`MB;ps5`** as long as that shortcut matches only one configured media player. Identifiers match without regard to letter case. An ambiguous shortcut displays a message asking for a longer suffix instead of choosing a random player.

With `MB` (no suffix), the widget checks the media-player entity assigned to the Text button's command, the activity's configured artwork/media source, its slider association, media-player widgets placed on its pages, and included media-player entities. When there is exactly one configured media player, it also works without explicit association. If the activity has no unique usable association and multiple players are configured, use a short explicit selector such as `MB;ps5`.

The Text widget becomes a **horizontal looping coverflow directly inside the activity grid cell**, not a popup. Give it at least **2 columns by 2 rows** (more space produces a better coverflow). Smaller cells show an inline resize hint rather than overlapping controls.

Swipe horizontally to select a cover, tap a centered item to play it or browse a folder, use the back arrow to return, or use refresh to reload. The browser loads additional content through paginated `browse_media` calls and plays items through `play_media`.

The target media player must expose the `browse_media` feature. The inline browser only fetches while the activity is on and its UI page is visible. The existing media-player widget and fullscreen browser remain unchanged.
