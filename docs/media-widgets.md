# Media-player widget settings

Open **Settings → Media player widgets**.

The four controls below the activity media-player widget can be shown or hidden separately:
- Shuffle
- Repeat
- Media browser
- Source selection

Previous **Hide media player controls** setting is migrated as the initial default for each new control. Individual selections are saved under `ui/showMediaShuffle`, `ui/showMediaRepeat`, `ui/showMediaBrowser` and `ui/showMediaSource`.

## Layout presets

- **Standard:** original artwork/title/artist/progress layout.
- **Compact:** side-by-side small artwork and metadata, without the bottom control row.
- **Artwork only:** image fills the whole media tile and hides text and controls.
- **Expanded:** larger typography and a control row at lower widget heights.

The preset is global across media-player widgets.

## Activity artwork source

Choose an activity, then choose the media-player entity whose album/movie art and metadata should be displayed in that activity's media-player widgets. The mapping is stored in `ui/activityArtworkSources`, keyed by activity ID. **Use activity widget media player** removes the mapping, preserving original behavior.

This controls **displayed artwork/metadata only**; playback commands on a media widget still go to the media-player entity configured in the activity UI. The selected entity must be configured and available to the Remote UI.

No changes are made to firmware or the Core API.
