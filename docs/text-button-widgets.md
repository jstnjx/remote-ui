# Custom Text Button widgets

The custom Remote UI recognizes special Text Buttons on an activity UI page, with the **Text** content in this format:

```text
WIDGET_TYPE;OPTIONAL_ENTITY_ID
```

Entity IDs are optional. Configure a regular **Text** widget in the Core Web Configurator; no firmware or Core API schema modification is needed.

| Text Button content | Result |
|---|---|
| `ACTIVITY_LAUNCHER` | Open a popup list of available activities; select an activity to start it |
| `ACTIVITY_LAUNCHER;uc.main.example-activity-id` | Start a specific activity immediately |
| `ACTIVITY_SWITCHER` | Open the activity switcher popup, even when an ID is provided |
| `KEYBOARD_SHORTCUT` | Open the native keyboard for the activity's primary media player, or choose one |
| `KEYBOARD_SHORTCUT;uc.integration.example-player` | Open the native on-screen keyboard for that media player |
| `APP_LAUNCHER` | Choose a configured Select or Media Player entity to open apps/games |
| `APP_LAUNCHER;uc.integration.example-select` | Show a Select entity's options as launchable apps/games |
| `APP_LAUNCHER;uc.integration.example-player` | Open the target Media Player's existing media browser if supported |

Aliases: `KEYBOARD` = `KEYBOARD_SHORTCUT`, `GAME_LAUNCHER` = `APP_LAUNCHER`.

Text after the first semicolon is treated as the optional entity ID; leading/trailing spaces are trimmed. The widget uses the Text Button's grid position and size.

## Commands and compatibility

**Activity Launcher** uses the existing `activity.start` command and the activity screen's normal navigation path.

**Keyboard Shortcut** reuses the native Qt Virtual Keyboard and the same input/send dialog as the sensor-triggered keyboard, but without requiring a sensor to turn On. It sends `keyboard.text_set` with `{text: ...}` only after explicit Send/Enter. The target media-player integration must support that command.

**Application / Game Launcher** uses existing integration capabilities: if the target is a **Select** entity, it displays its `options` and calls `selectOption`. If the target is a **Media Player** that supports media browsing/search, it reuses the existing media browser and its `play_media` command flow. It cannot invent a list of applications for integrations that expose neither feature.

The widgets are native QML components registered as qrc resources and remain available without a network-side widget server.
