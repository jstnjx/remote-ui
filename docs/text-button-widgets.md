# Keyboard shortcut Text widget

The custom Remote UI supports one simple Text widget shortcut. The activity/game/app launchers have been removed.

## Set up

1. In the Web Configurator, open an activity's UI page.
2. Add an ordinary **Text** widget.
3. Set its text to `KB` (only two characters, so it fits the stock text limit).
4. Position and size it, then save.

The widget renders only a **keyboard icon on plain black**, with no title, label or additional popup layers.

## Target media player

The keyboard target is resolved in the following order:
1. An optional explicit ID in `KEYBOARD;media_player_id` (legacy syntax; may exceed the Text widget limit).
2. The Text widget's normal command `entity_id`, if configured.
3. The first media-player target in a keyboard automation rule for the same activity.
4. The activity's configured media-player widget entity.

For the easiest setup, configure a rule in **Settings → Keyboard input automation** for the activity, with at least one media player target. That rule's sensor does **not** need to turn On when using the manual keyboard icon.

Clicking the icon opens the native keyboard overlay. A native **return/send arrow icon** appears inside the keyboard directly to the right of Backspace (no uppercase SEND label). Pressing Send submits `keyboard.text_set` with the text. Closing/hiding the keyboard closes the entire overlay. There are no separate Cancel or Send buttons and no explanatory text above the field.

The selected integration must support `keyboard.text_set` on its media-player entity.

For backward compatibility `KEYBOARD` and `KEYBOARD_SHORTCUT` are recognized in addition to `KB`. Existing `ACTIVITY_LAUNCHER`, `ACTIVITY_SWITCHER`, `APP_LAUNCHER`, and `GAME_LAUNCHER` widget interpretations have been removed; their text is treated as ordinary text.
