# EDGE Observatory

EDGE Observatory is the replacement macOS app for the local read-only EDGE dashboard.
It uses one borderless `WKWebView` app process, direct EventKit access, and bounded background Herdr snapshot queries.
It does not run an HTTP server, accept external navigation, or expose arbitrary command execution to bundled JavaScript.

The app only loads resources from its own bundle and only permits the message names `agents`, `calendar`, and `focusAgent`.
Herdr output is reduced to pane id, agent name, status, workspace, and unread state before it reaches the page.
The Herdr executable is selected from a fixed allowlist and each query is terminated after four seconds.

The window is shown only when a display has the exact localized name `XENEON EDGE`.
It is borderless, uses the full display frame, and follows display hotplug notifications.
The app identity is stable at `~/Applications/EDGE Observatory.app` and bundle id `local.edge.observatory`.

## Build and test

```sh
bash scripts/build-edge-observatory.sh
xcrun swiftc packages/edge-observatory/UnreadTracker.swift packages/edge-observatory/test_unread.swift -o /tmp/edge-unread-test
/tmp/edge-unread-test
node --check packages/edge-observatory/app.js
python3 -m unittest discover -s config/edge-dashboard -p 'test_*.py'
```

Do not launch the app or touch runtime during build validation.
The `observatory` service mode is opt-in and leaves the existing `legacy` stack unchanged by default:
set `darwinModules.edgeDashboard.mode = "observatory"` only after physical acceptance.
The old HTTP service, Chrome dashboard, calendar helper, and touch app must remain untouched until that acceptance is complete.

## Native touch runtime and license

The pinned Objective-C runtime is embedded in-process from upstream revision `9a6823fe3f55448bd0ac233531dc6d73fbff19c5`, with `packages/xeneon-touch-support/safety.patch` applied.
Its upstream menu-bar shell and `main` function are excluded; `TouchRuntime.m` exports only create/start and stop entry points for this app.
The runtime remains GPLv3-only; the complete upstream text is retained in `TOUCH-LICENSE`.

Before physical use, grant Accessibility and Input Monitoring to `EDGE Observatory.app` itself.
Verify exact-display placement, unplug/replug hotplug behavior, calendar permission, Herdr unread transitions, and touch safety.
