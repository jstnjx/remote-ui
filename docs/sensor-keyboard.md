# Keyboard input automation and Apple TV

The activity-page `KB` Text widget opens the Remote's native virtual keyboard. Text is submitted with the keyboard's **return-arrow Send key**; closing the virtual keyboard also closes the full-screen overlay. There is no extra Send button.

## Supported Apple TV text transport (no webhook)

Use the existing [Apple TV Keyboard integration](https://github.com/jstnjx/uc-intg-appletv-keyboard) for real tvOS text entry. This integration exposes a **Media player** named **Apple TV Keyboard - <device name>** with a Search feature. Its `search_media` implementation calls `pyatv.keyboard.text_set(query)` on the focused tvOS field. The Remote UI's `KB` shortcut now submits the entered text through that **existing media-player Search action**.

1. Install and pair the **Apple TV Keyboard** custom integration on the Remote (with Companion credentials) if it is not already installed.
2. Add its **Apple TV Keyboard - <device name>** media-player entity to the Remote.
3. Under **Settings → Keyboard input automation**, choose your activity and select the **Apple TV Keyboard:** target in **Text input targets**. Deselect the ordinary Home Assistant Apple TV **Remote:** target if you no longer need it. A selected native Apple TV Keyboard target takes precedence over an older Remote target automatically.
4. Place a regular **Text** widget containing `KB` on the activity UI page. Focus an editable/search field on the Apple TV, open the shortcut, enter text and press the keyboard's native **Send** arrow.

**This is the same Core API search request that Browse → Search uses**, not a separate keyboard command. The keyboard invokes `mediaPlayer.searchMedia(text, "", "", [], 10, 1)`. The existing integration handles search through Companion and reports either `Sent: ...` or `Text not sent` with the reason. Because dismissal of the keyboard closes its overlay, any asynchronous failure is also shown as a Remote notification.

The UI can automatically match a Home Assistant Remote/media-player to an Apple TV Keyboard entity **only when their normalized device names match uniquely**. Otherwise explicitly choose the `Apple TV Keyboard:` entry. This avoids accidentally sending text to the wrong Apple TV when more than one is configured.

### Stale Apple TV Keyboard entity IDs

The November 2 integration log shows a **removed Apple TV Keyboard entity** repeatedly being subscribed while the integration reports a different active entity. This can happen after re-pairing or reconfiguring the integration. The `KB` shortcut now tries to recover an obsolete `.keyboard` entity ID **only when exactly one configured live keyboard entity can be identified**. If several Apple TVs are present, it does not guess.

For a durable configuration, remove the obsolete media-player entry from the Remote's entity list, add the current **Apple TV Keyboard - <device>** entity again, and reselect it in **Settings → Keyboard input automation → Text input targets**. The removed and active IDs are shown in the integration logs.

The `KB` shortcut now uses **the same `EnterKeyAction.Search` and direct `TextField.onAccepted` binding as the working Media Browser Search field**. Its native keyboard key still displays the return-arrow Send icon, but Qt handles the key event normally without the earlier custom MouseArea intercepting it. The code reads the underlying TextField text and invokes the same media-player `searchMedia()` method as Browse → Search. Dismissing the keyboard still closes the overlay.


## Why Home Assistant's Remote entity cannot perform this

The Home Assistant Apple TV `remote.send_command` service only accepts supported **remote control method names**, not `keyboard.text_set <text>`. The device logs showed `ValueError: Command not found. Exiting sequence` when the previous Remote UI tried that string. A successful UC Core ACK only means the command was submitted; it does not prove that tvOS accepted it.

For Home Assistant itself, `apple_tv.set_keyboard_text` accepts `config_entry_id` and `text`. The current UC Home Assistant Remote entity does not expose that arbitrary service action. The dedicated Apple TV Keyboard integration provides a text transport without a webhook, long-lived HA token or changes to Home Assistant.

## Other devices

For non-Apple-TV integrations, the original `keyboard.text_set` media-player command and `remote.send_cmd` path remain available if the respective integration implements them. The `mediaPlayerIds` configuration key is unchanged for compatibility with existing keyboard rules. Sensors optionally trigger prompts when switched on. A manual `KB` shortcut needs only an activity and an appropriate selected target.

## Troubleshooting

If you see **Apple TV Keyboard is unavailable** or **did not respond**, inspect the custom integration's connection/pairing status. The Remote logs may show a reconnect loop for the `appletv_keyboard` driver. If you see **Apple TV keyboard is not focused**, open a text field on tvOS before pressing Send. Successful text entry replaces the current field contents (matching `text_set`).

The later November 2 logs show **no `search_media` request arriving at the Apple TV Keyboard integration**, even though its Search feature is advertised. They also show repeated WebSocket keepalive timeouts and a large number of artwork downloads cancelled shortly after being started. The UI now coalesces rapid artwork URL updates for 350 ms and ignores stale cancellation warnings, reducing this avoidable load.

No end-to-end successful send was present in the provided logs. After installing the updated UI, confirm that the Apple TV Keyboard integration log receives `search_media` when the Send arrow is pressed. If it does, the next issue to check is tvOS keyboard focus and Companion connectivity.
