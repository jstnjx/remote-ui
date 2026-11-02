# Inline media browser (activity UI)

Place a **Text** button/widget on any activity UI page. Set its text to:

```text
MB;media_player_entity_id
```

Replace `media_player_entity_id` with the actual UC media-player entity ID (for example, `media_player.music_assistant`). This is case-insensitive for the `MB` marker, but the entity ID must match exactly. The Text widget becomes a **horizontal, looping coverflow** directly in its assigned grid cell; it does **not** open the normal Media Browser popup.

Use a widget spanning **at least two columns and two rows** (larger works better). A cell that is too small shows an inline resize hint instead of overlapping controls.

Swipe left or right to browse the covers. Tap a side cover to center it; tap the centered cover to open a browsable folder, or play an item. The header back arrow returns to the previous folder and the refresh icon reloads the current folder. Folder navigation and media playback use the selected entity's existing `browse_media` and `play_media` API actions. Browse results are paginated as you reach the end of a loaded batch.

The media player must support the `browse_media` feature. The widget only fetches media while its activity screen/page is visible and the activity is on. If the player is offline or doesn't support browsing, an inline message appears. The existing `media_player` widget and full-screen media-browser popup remain unchanged.
