# Sensor-triggered keyboard input

The custom remote UI can offer its **native on-screen keyboard** while an activity is open, based on a configured On/Off sensor. This behavior lives entirely inside the remote UI.

## Configure

1. On the remote, open **Settings → Keyboard input automation**.
2. Select an **Activity**.
3. Select an **On/Off sensor** belonging to that activity. The picker offers binary sensors and sensors currently reporting a raw `on` or `off` value.
4. Choose a **Target media player** from configured, loaded media-player entities (it may be outside the activity).
5. Return to the selected activity. When the sensor reports `on`, a prompt offers **Open keyboard**. Dismissing it does not reopen the prompt until a new Off-to-On cycle.

The popup uses the stock Remote UI's input field and Qt Virtual Keyboard. Press **Send** (or accept on the keyboard) to send:

```json
{
  "entity_id": "selected-media-player-id",
  "cmd_id": "keyboard.text_set",
  "params": {"text": "text typed on the remote"}
}
```

The target integration must support the `keyboard.text_set` command on its media-player entity; the standard media-player entity does not automatically guarantee support for every custom command.

## Behavior and safety

- No command is sent merely because the sensor turns On. The user must open the keyboard and submit nonempty text.
- The sensor's **raw** value is read instead of its translated presentation text, making it independent of the Remote UI language.
- Off dismisses the popup and allows the next On transition to prompt again.
- Prompts only appear when the configured activity is open and On.
- Sensor and media-player selections are stored in the remote UI's existing persistent QSettings file, not in the Core API.
- Changing the activity clears the old sensor selection; choosing **None** disables the corresponding selector.
- The popup checks that the configured media player is available before sending the command.
