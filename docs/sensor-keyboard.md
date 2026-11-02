# Context-aware keyboard automation

Go to **Settings → Keyboard input automation** to create rules scoped to an activity. A rule selects one activity, one or more optional on/off sensors, one or more media-player targets, a prompt, and an optional Home Assistant Apple TV webhook.

- **Sensor prompt:** when any selected binary sensor reports `on`, the activity offers the native keyboard once, until all sensors return `off`.
- **Manual keyboard button:** place a Text widget with `KB` in an activity UI page. A rule for that activity can specify the target media player and, optionally, the Home Assistant webhook. No sensor is needed to use the manual button.
- **Native command:** by default, Submit uses the UC Core entity command `keyboard.text_set`, with a `text` parameter. **Only** media-player integrations that implement that command can use this path.

## Home Assistant Apple TV

A Home Assistant Apple TV media-player entity on the remote does **not** implement the UC `keyboard.text_set` command. The Apple TV Home Assistant integration uses the **`apple_tv.set_keyboard_text`** service/action and requires the Apple TV's **config entry ID**. To bridge the two without putting a Home Assistant API token on the remote, create a local webhook automation:

1. Open the Apple TV's configuration page under **Home Assistant → Settings → Devices & services → Apple TV** and copy the configuration-entry ID from the last part of the URL.
2. Create an automation in Home Assistant using this YAML. Replace `CHANGE_TO_A_LONG_RANDOM_SECRET` with your own unpredictable webhook ID and `YOUR_APPLE_TV_CONFIG_ENTRY_ID` with your actual ID.

```yaml
alias: UC Remote - Apple TV Keyboard
mode: queued
triggers:
  - trigger: webhook
    webhook_id: CHANGE_TO_A_LONG_RANDOM_SECRET
    allowed_methods:
      - POST
    local_only: true
actions:
  - action: apple_tv.set_keyboard_text
    data:
      config_entry_id: YOUR_APPLE_TV_CONFIG_ENTRY_ID
      text: "{{ trigger.json.text }}"
```

3. In the remote, open **Settings → Keyboard input automation**. Add/select a rule, choose the activity and your Home Assistant Apple TV media player under **Target media players**, then enter and save the **Home Assistant Apple TV webhook** URL:

```text
http://HOME_ASSISTANT_IP:8123/api/webhook/CHANGE_TO_A_LONG_RANDOM_SECRET
```

4. With the Apple TV's **on-screen text field focused**, open the `KB` widget in that activity, enter your text and press the **return-arrow Send key**. The remote POSTs the text to the configured webhook; the HA automation then calls `apple_tv.set_keyboard_text`.

The manual `KB` widget automatically uses the webhook from the matching rule for its activity and selected media player. Sensor-triggered prompts use the same rule. A webhook-enabled rule delivers to the Apple TV configured in its HA automation, rather than broadcasting text to every selected native media player; configure a separate rule and webhook for each Apple TV. **Do not expose your webhook ID publicly.** Keep `local_only: true`, use a long random ID, and use a reachable Home Assistant LAN address. The remote sends only the `text` field and needs no new long-lived access token.

The Apple TV must be on, reachable, and showing a focused editable field. Home Assistant returning HTTP 2xx means the webhook request was accepted; it does not prove that tvOS accepted the text. If the action itself fails, inspect the HA automation trace. Failed network/webhook requests keep the remote's keyboard open and show an error.

## Compatibility

Existing rule preferences remain under `ui/keyboardRules` in QSettings and existing rules keep the native command path unless a webhook is configured. Rules do not depend on the activity's `includedEntities` list; sensor IDs placed on the activity UI are also supported. The original home and other media-player commands are unaffected.
