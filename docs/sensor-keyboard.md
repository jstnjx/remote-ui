# Context-aware keyboard automation

Go to **Settings → Keyboard input automation** to configure a rule for an activity. Rules can use one or more On/Off sensors to prompt for input, or the short `KB` Text widget to open the same native keyboard manually.

## Apple TV: choose the Remote entity, not the Media Player

The **Home Assistant Apple TV Remote** entity supports `remote.send_command`. For Apple TV text entry, send the exact command that works in Home Assistant:

```yaml
action: remote.send_command
target:
  entity_id: remote.apple_tv_4k_wohnzimmer_gen_2
data:
  command:
    - "keyboard.text_set Hello from UC Remote"
```

This is handled **directly through the existing Unfolded Circle Home Assistant integration**, without any Home Assistant webhook, API token or helper automation.

1. On the UC Remote, open **Settings → Keyboard input automation** and create/select a rule.
2. Select the activity where you placed your keyboard button.
3. Under **Text input targets**, choose the entry labeled **Remote:** for the Apple TV's Home Assistant remote entity (`remote.apple_tv_4k_wohnzimmer_gen_2` in Home Assistant). **Do not choose its Media player:** entry.
4. On that activity's UI page, add a **Text widget** containing `KB`. The widget turns into a keyboard icon.
5. Focus the editable field on the Apple TV, tap the `KB` widget, type text, then tap **Send text** above the keyboard or use the native return-arrow **Send** key. Both invoke the same handler.

The Remote UI builds the UC Core entity command:

```json
{"cmd_id":"remote.send_cmd","params":{"command":"keyboard.text_set Hello from UC Remote"}}
```

The Home Assistant integration translates `remote.send_cmd` to `remote.send_command` for the selected remote entity. Text, including spaces and punctuation, remains a **single command string**, just as in your working Home Assistant automation.

The entity ID shown by the UC integration may have a prefix different from the Home Assistant ID. Select the correct remote **by name** in the target picker; you do not need to rename the entity or fit its full ID into the activity Text widget.

If your `KB` Text widget still has an old command target attached, the keyboard rule's selected **Remote** takes precedence. When a Home Assistant media-player entity has a companion Remote entity with the same integration and device suffix, the keyboard can also redirect to that Remote. Otherwise, it displays a message asking you to select the Remote instead of attempting an unsupported media-player command.

The keyboard editor **does not close when the virtual keyboard hides**; the text remains available for the explicit Send button. This prevents an Enter-key timing difference from silently discarding a submission. Core command failures are reported through the usual Remote UI notifications.

## Other integrations and existing rules

The original `keyboard.text_set` command with `{"text":"..."}` is retained for media-player integrations that implement it. The keyboard target picker now lists both **Remote** and **Media player** entities; existing `mediaPlayerIds` rule values are preserved to avoid changing user settings.

A sensor-based rule prompts when any selected On/Off sensor turns on and re-arms when all sensors turn off. A manual `KB` widget uses the first configured target for that activity, or the Text button's explicitly configured command target. No sensor is required for manual use.

An ordinary media-player entity does not automatically support keyboard text commands, and the Home Assistant Apple TV media-player entity is **not** the supported destination for `keyboard.text_set`. With Apple TV, always target the Home Assistant **remote** entity.

A successful UC command dispatch does not by itself prove that tvOS accepted the text; the Apple TV must have an active text-entry field. For further problems inspect the Home Assistant integration and Apple TV logs.
