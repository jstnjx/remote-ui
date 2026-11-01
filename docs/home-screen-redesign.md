# Optional Home Screen Redesign

This redesign is **disabled by default**. It is a visual overlay **only on the first page** of the original home screen, not a replacement for the original `Page.qml` component or the underlying page data. All existing pages, editing, D-pad navigation, activities, integrations, profile/settings menu and activity screens remain intact. Restricted profiles always use the original home screen so the new launcher cannot expose entities not assigned to their profile. If the optional home QML fails to load, its Loader reports the error and exposes the original first page.

## Enable

On the remote, open **Settings → Home screen**.

- **Use redesigned home screen**: Off restores the original UI immediately; On enables the new first-page layout.
- **Home layout**: choose Modern Grid, Media Focus, Living Room Hub or Minimal.
- **Show clock and date**: uses the remote's own `ui.time` and existing 12/24-hour setting.
- **Show activity shortcuts**: uses currently configured activity entities.
- **Show now playing**: uses the first available media player, preferring currently playing or paused players, with artwork, title, artist and previous/play-pause/next controls.
- **Show quick controls**: uses configured light and switch entities. Tapping one opens its existing entity control screen; no new unverified command type is introduced. If no controls exist, a Settings shortcut is displayed when permitted by the active profile.
- **Show page indicators**: native dots for the first eight pages, with tap-to-switch; other existing pages are still accessible through standard navigation.

All options persist in QSettings, under `ui/redesignedHomeEnabled`, `ui/homeScreenLayout`, and the `ui/homeShow*` keys.

## Layouts

1. **Modern Grid**: clock, 2×2 activity shortcuts, compact now-playing card, quick controls and page dots. Recommended default.
2. **Media Focus**: clock, large album-art/media card with transport controls, compact activity shortcuts, quick controls and page dots.
3. **Living Room Hub**: room-style overview card with actual activity/quick-control counts, activity shortcuts, small media card, quick controls and page dots.
4. **Minimal**: large clock with generous black space, a compact activity dock, optional media and quick controls, and page dots.

Appearance uses the **accepted native design system**, not the earlier custom bordered-card style:
- Black page background via `colors.bg`; flat `colors.surface` tiles without permanent card outlines.
- Native text roles `fonts.display()`, `fonts.heading()`, `fonts.label()`, `fonts.help()`, `fonts.value()` with `colors.textPrimary` / `colors.textSecondary`.
- `Components.Selectable { style: "fill" }` for activity/media/quick tiles; selection appears when using D-pad, not as a permanent border. The normal haptic hit targets and `ui.cornerRadiusSmall` remain.
- The primary redesigned clock is centered in the home content. **The stock StatusBar hides only its time text** while the redesigned home is active. Battery, Wi-Fi, profile and connection indicators stay visible. Turning the redesign off or leaving home restores the stock top-bar clock.
- Unconfigured/fake room names are not shown; the Living Room Hub uses a neutral `Home` overview with actual entity counts.

This aligns with `docs/design-system.md`, including 20 px content gutters, non-decorative status colors, Poppins for labels and Space Mono for date/time values.

## Controls and reliability

- Touch an activity tile to open its **existing** activity detail screen. Starting/stopping it still uses the standard activity UI.
- Touch the now-playing metadata to open that entity's detail screen. The three transport buttons use its existing `previous()`, `playPause()`, and `next()` methods, only when the entity is enabled.
- Quick control tiles open the corresponding native light/switch detail screen.
- D-pad Left/Right/Up/Down moves selection; OK opens the selected shortcut; HOME resets selection; Right at the last item switches to the next page. Long HOME still opens the original edit/page menu.
- Tapping page indicators opens an existing page; the normal home page model remains loaded underneath.
- Editing mode and the original page menu temporarily hide the new overlay. On failure to instantiate the optional `HomePage.qml`, the original page stays visible and functional.
- No ucOS, Core API, device API or Web Configurator schema changes are needed.

## Layout sizing and overflow protection

All four layouts are bounded to the actual device viewport (480×800 on Remote 3
and 480×854 on Remote Two) rather than a fixed simulator mockup size:

- The content area uses a clipped `Flickable` whose height is derived from the
  visible layout's implicit content height; activity lists can grow and scroll
  without painting over adjacent cards.
- Modern Grid and the compact Media Focus / Hub grids compute tile widths from
  the available width and 10px gutter. Quick controls and the Minimal dock
  display icons only when their tiles are too narrow for the native 30px labels.
- Compact media keeps artwork, one-line metadata and the transport row in
  separate regions. Media Focus reserves distinct vertical bands for album
  artwork, up to two lines of title, artist and transport controls.
- Page indicators remain in a fixed 44px bottom region, separate from the
  scrolling content; the scroll viewport reserves space for them.
- D-pad focus scrolls the **actual selected tile** into view rather than jumping
  to the bottom after the fourth activity.
- All tiles and artwork regions use `clip: true`, and long metadata is elided.
  A geometry sanity check runs in Code Guidelines CI.

The Qt build check does not render the UI, so real-device confirmation remains
necessary after installing the revised version.

## Recovery

If the new layout does not behave correctly, open **Settings → Home screen → Use redesigned home screen = Off**. This does not remove data, settings, or activity configuration. The default remains the stock UI even after installation.

The redesigned home is in `src/qml/components/home/`: `HomePage.qml`, `ActivityTile.qml`, and `MediaCard.qml`. The main container only loads it on demand and routes a few hardware actions to it when present.
