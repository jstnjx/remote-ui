# Context-aware keyboard automation

Navigate to **Settings → Keyboard input automation** to create multiple independently configured rules.

Each rule supports:
- **Activity**: only active while that activity is open and On
- **On/Off sensors**: select one or more configured binary On/Off sensors, or sensors placed on an activity UI page
- **Media-player targets**: select one or more configured media players
- **Prompt text**: edit the prompt shown on the activity UI before opening the native keyboard

The sensor picker no longer depends on `activity.includedEntities`; sensor widgets remain selectable even when the Core API omits sensors from included entities. Any selected sensor reporting raw `on` fires a rule; the rule rearms only after **all** its sensors report `off`. Dismissing the prompt leaves it suppressed for that On cycle. Each rule has its own rearm state.

After choosing **Open keyboard**, the remote uses its native Qt Virtual Keyboard and sends the entered text to **each available selected media player**:

```json
{"cmd_id":"keyboard.text_set","params":{"text":"Your text"}}
```

Each command uses the selected target's media-player entity ID. The media-player integration must implement `keyboard.text_set`; an ordinary media-player entity does not guarantee support. Text is sent only on an explicit Send/Enter, never on every keypress.

## Compatibility and limits

The original single-activity, single-sensor, single-player preference is automatically migrated into the first rule when `ui/keyboardRules` is missing. New rules are saved in `ui/keyboardRules` using QSettings; removing a rule does not alter activities or entities on the Core API.

Selectors list entities loaded by the UI; activity-page sensor widget IDs are also discovered and loaded. A sensor not yet configured or loaded may initially display its ID rather than its friendly name.

The remote must have the selected activity open and its state On. The UI evaluates raw sensor values `on` and `off` rather than translated labels. The popup is dismissed if the activity closes or sensor returns to Off. Multiple simultaneous rules are offered sequentially rather than opening multiple overlapping dialogs.
