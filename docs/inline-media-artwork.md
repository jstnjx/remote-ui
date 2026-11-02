# Inline media-player artwork widget (activity UI)

Use the stock **Text** widget in the activity UI editor to show a media player's live artwork directly on the grid. The widget replaces the Text button with **artwork only**, without a title, transport controls, popup, or background button action.

## Setup

1. Add a **Text** widget to an activity page.
2. Set its text to the **media-player entity ID**, without an `MB;` prefix.
3. Resize the widget to the desired artwork area. A square cell or 2×2 grid cells works well.

Examples:

| Text widget content | What it does |
| --- | --- |
| `ps5_connect_driver.main.media_player.ps5_10_1_1_30` | Full entity ID (when the editor accepts it) |
| `ps5_10_1_1_30` | Exact final segment of that entity ID |
| `ps5` | Short prefix of that segment, **if only one configured media player matches** |

The stock Text editor has a limited character count. **For PS5 Connect, set the Text to `ps5`** if it uniquely identifies your media player; otherwise use `ps5_10_1_1_30` or the shortest unambiguous prefix.

The artwork updates from the media player's existing `mediaImage` property and follows the remote's **Fill Media Artwork** setting (crop-to-fill versus fit). A music icon is displayed while there is no artwork or if its image cannot be loaded.

**Only actual, uniquely resolved media-player IDs or ID suffixes are converted.** Ordinary Text buttons, the `MB`/ `MB;...` browser shortcuts, keyboard `KB`, and RTSP widgets are unaffected. Unknown short text remains a normal Text button.

There is no change to the Core-API UI schema or the media player's own entity ID.
