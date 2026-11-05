# Lovelace dashboard rendering for Remote-UI (experimental)

The Remote-UI can display Home Assistant dashboards using an optional local
Qt WebEngine module or the companion remote Chromium renderer.

## Remote rendering (Option B)

Requires a Linux/macOS computer with Python 3.10+ and a Chromium-compatible
Playwright installation. Run on a **trusted LAN**; the renderer accepts touch
input and provides images of a logged-in dashboard. **Never expose the HTTP
port to the Internet**. The service validates dashboard URLs against HA_ORIGIN.

```bash
cd tools/lovelace-renderer
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
python -m playwright install chromium
export HA_ORIGIN="http://homeassistant.local:8123"
python login.py
# Complete Home Assistant authentication in the opened window, then press Enter.
LOVELACE_HOST=0.0.0.0 python server.py
```

In Remote Settings → Home Assistant dashboards, choose Remote browser service,
paste the Lovelace URL (including its view path), and set the renderer address to
`http://RENDERER-IP:8765`. Ensure the remote can reach the renderer. The
session is stored in `browser-profile/` on the rendering host: protect that
directory and do not commit it to version control.

**Limitations:** approximately 1–3 screenshots/s, basic touch/drag/scroll,
no remote keyboard yet, no production-grade authentication for the renderer
endpoint, and no server-side TLS. Constrain access using host firewall and
isolated LAN/VLAN. First-time login needs an interactive graphical session
on the rendering host. Use an HTTPS reverse proxy when applicable.

## Local rendering (Option A)

`LocalBrowser.qml` uses `QtWebEngine 1.10` and loads only when a
dashboard selects the local engine. The existing Remote-UI firmware uses
statically linked Qt and does **not** include Qt WebEngine. Consequently,
this engine **will display a clear unavailable message on standard devices**.
Do not assume it works on actual Remote 2/3 hardware until a dynamic browser
runtime and platform compatibility have been confirmed and deployed.

## Integration

Dashboard definitions are saved locally in `UC_CONFIG_HOME/config.ini` via
the Config singleton. Settings → Home Assistant dashboards manages the URLs.
The home screen adds an HA dashboard launcher with a dedicated full-screen
viewer. Page-designated dashboards have navigation dots; overlay-designated
dashboards open from the launcher. This is a standalone dashboard viewer,
**not** native insertion into the existing controller-defined PathView page
model. Dashboard touch events never propagate to the native page behind it.

## Troubleshooting touch and flicker

The Remote UI uses double-buffered JPEG images to keep the previous screenshot
visible until a new JPEG has completed downloading. Clicking and swiping are
forwarded over HTTP to the renderer, where Chromium dispatches mobile touch
events. **Update both the Remote UI binary and this renderer** after pulling
the latest feature branch; a new UI with an old renderer will not fix scrolling.

Restart the renderer after updating:

```bash
cd tools/lovelace-renderer
source .venv/bin/activate
export HA_ORIGIN="http://HOME-ASSISTANT-IP:8123"
LOVELACE_HOST=0.0.0.0 python server.py
```

Verify the renderer is listening:

```bash
curl -i http://RENDERER-IP:8765/health
```

After you have opened a dashboard using the `/frame` endpoint, test the input
endpoint with a safe location on the dashboard (replace the dashboard URL):

```bash
curl -i -X POST \
  --data '{"type":"click","x":220,"y":200}' \
  -H 'Content-Type: text/plain' \
  'http://RENDERER-IP:8765/input?url=http%3A%2F%2FHOME-ASSISTANT-IP%3A8123%2Flovelace%2Fremote3%3Fkiosk'
```

You should see `{"ok": true}` and an `Input click` log entry. If no
input log appears when touching the remote, verify the Remote UI has the latest
binary and the server firewall allows POST requests on port 8765.
