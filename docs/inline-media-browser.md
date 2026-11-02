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

The Text widget becomes a **horizontal looping coverflow directly inside the activity grid cell**, not a popup. The browser has a **black background** and large center artwork; there is no "Browse media" heading or refresh button, so the covers occupy most of the widget. Give it at least **2 columns by 2 rows** (more space produces a better coverflow). Smaller cells show an inline resize hint rather than overlapping controls.

Swipe horizontally to select a cover. **Tap any folder or browseable playlist once to open it**, even when it is not the centered cover. For a playable item, tap to select it and tap the centered cover to play. A back arrow appears at the upper-left inside folders; it restores the prior level's covers, pagination and selection. Nested browsing uses the exact `media_id` and `media_type` supplied by the integration rather than trying to reconstruct a folder path.

The inline browser now retains each server response's **container metadata**, just like the full-screen media browser. Inside playlists and albums, when the integration returns a playable container but no browseable child items, that container is displayed as a tappable **playable cover** instead of a misleading "No media found" message. If a folder really contains nothing, the widget displays "This folder has no media". Integrations that return embedded child items without a separate browseable ID are supported.

The browser loads additional content through paginated `browse_media` calls and plays items through `play_media`. Request IDs and a navigation revision prevent old responses or delayed selection updates from overwriting the contents of a newer folder. On failure, the widget logs the request ID, depth, media ID, media type and error code without logging private media titles or credentials.

The target media player must expose the `browse_media` feature. The inline browser only fetches while the activity is on and its UI page is visible. The existing media-player widget and fullscreen browser remain unchanged.
