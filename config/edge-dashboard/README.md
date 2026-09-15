# EDGE dashboard

A local, read-only dashboard for the XENEON EDGE's 2560 x 720 canvas.
The approved migration is implemented in `packages/edge-observatory/` as one Swift macOS app with a bundled WKWebView, direct EventKit access, bounded Herdr queries, and no HTTP server.
The existing Python/Chrome stack remains the default until physical acceptance tests pass.
The clock and Herdr agent roster are live.
Calendar availability depends on macOS permission and the selected calendar being synced.
The display summary is static configuration, not hardware telemetry.

## Run

Start the loopback service in a terminal:

```bash
python3 config/edge-dashboard/server.py
```

Then open the display:

```bash
scripts/open-edge-dashboard.sh
```

Requires macOS, Python 3, Google Chrome, curl, and Herdr on PATH.
The service listens only on `127.0.0.1:8767`.
It rejects foreign Host and Origin headers and serves only explicitly allowed files.
It has no mutation endpoints and does not expose terminal contents, transcripts, credentials, or session paths.
The browser polls agent status every second and marks retained data stale if polling fails.
Agent status is reported directly by Herdr, not independently inferred or verified.
Task descriptions, recent results, and agent sessions outside the current Herdr session are not yet supported.

The launcher uses a dedicated Chrome profile at `~/Library/Application Support/edge-dashboard/chrome`.
It moves the dashboard to its AeroSpace workspace before requesting native fullscreen.
Native fullscreen uses a separate macOS Space; placement transitions still need physical verification.
A single launchd login service is defined in `modules/darwin/services/edge-dashboard.nix`.
It takes effect after Darwin activation.
Stop the server with Ctrl-C and close the browser window to stop the dashboard.

## Calendar via macOS

Google Calendar is read through Apple Calendar sync, without Google OAuth credentials.
Build and launch the local EventKit helper with `bash scripts/start-edge-calendar.sh`.
Grant EDGE Calendar full calendar access in macOS Privacy & Security settings.
The helper performs no writes to EventKit and selects exactly one calendar named `kisw@lunar.app`.
Missing or duplicate calendar names fail closed rather than including other calendars.
Only titles, start/end times, and all-day flags for remaining events today are exported.
The snapshot resides in `~/Library/Caches/edge-dashboard/calendar.json` with mode 0600 and refreshes every 30 seconds.
The service suppresses snapshots older than 90 seconds.
The helper is installed at `~/Applications/EDGE Calendar.app`; the supervisor starts it after login when the service is activated.
Real event retrieval remains unverified until calendar permission is granted.

## Validation

```bash
node --check config/edge-dashboard/app.js
bash -n scripts/open-edge-dashboard.sh
```

Browser checks cover desktop 2560 x 720, mobile 390 x 844, live agent rendering, and stale state after a failed fetch.
Host and Origin rejection can be checked against `/api/agents`.

## Unread agent responses

Cards turn amber and show NEW RESPONSE when Herdr reports done while unfocused, including the first observation, or when a sampled state changes from working to idle.
Focusing the pane clears the highlight; unread cards sort first.
Tracking is in server memory, survives browser reloads, and resets on server restart or session replacement.
Already-idle agents are not marked unread at startup.
This relies on Herdr lifecycle reporting and polling: missed working states, brief focus changes, or incorrect upstream idle states can prevent accurate detection.
Run transition tests with `python3 -m unittest discover -s config/edge-dashboard -p 'test_*.py'`.

## Single-service startup

`darwinModules.edgeDashboard.enable` enables one launchd service.
Its default `mode = "legacy"` keeps the currently working Python/Chrome stack unchanged.
The opt-in `mode = "observatory"` runs `~/Applications/EDGE Observatory.app` as the sole app process and does not start the old HTTP server, Chrome, calendar helper, or separate touch app.
The supervisor opens Chrome only while an exact `XENEON EDGE` display is reported by AeroSpace.
It closes its browser process on disconnection and reopens on reconnection.
Helpers restart if they exit; stopping the supervisor terminates its child processes.
AeroSpace itself remains an independent prerequisite.

The currently permission-approved calendar and touch app bundles in `~/Applications` remain prerequisites for legacy mode and are not rebuilt or stopped by this change.
Google Chrome must be installed in `/Applications` for legacy mode.
Do not activate Observatory mode or launch its touch runtime until physical acceptance is approved.
New untracked source files must be added to Git before the normal Git-flake switch wrapper can include them.
Login and unplug/replug behavior still require physical acceptance testing after activation.
