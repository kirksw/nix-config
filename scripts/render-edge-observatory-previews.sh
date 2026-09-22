#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-/tmp/edge-observatory-previews}"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if [[ ! -x "$chrome" ]]; then
  printf 'Google Chrome is required at %s\n' "$chrome" >&2
  exit 1
fi

rm -rf "$out"
mkdir -p "$out"
cp "$root/packages/edge-observatory/"{index.html,style.css,app.js} "$out/"

cat > "$out/native-shim.js" <<'JS'
'use strict';
window.webkit = {messageHandlers: new Proxy({}, {get: () => ({postMessage() {}})})};
JS

cat > "$out/fixture.js" <<'JS'
'use strict';
const params = new URLSearchParams(location.search);
applyTheme(params.get('theme') || 'observatory');
const now = new Date();
const later = minutes => new Date(now.getTime() + minutes * 60000).toISOString();
window.edgeNativeReceive('agents', {status: 'connected', updatedAt: now.toISOString(), agents: [
  {id: 'w-edge:p2', workspace: 'edge-observatory', agent: 'reviewer', profile: 'personal-default', status: 'done', unread: true, cost: 4.9, tokens: 22100},
  {id: 'w-main:p1', workspace: 'nix-config', agent: 'coder', profile: 'personal-default', status: 'working', unread: false, cost: 12.4, tokens: 84100},
  {id: 'w-pay:p3', workspace: 'payments-platform', agent: 'worker', profile: 'work-default', status: 'idle', unread: false, cost: 1.2, tokens: 6100},
  {id: 'w-long:p4', workspace: 'long-workspace-name-for-overflow-check', agent: 'scout', profile: 'work-experimental', status: 'working', unread: false, cost: 0.42, tokens: 2800},
  {id: 'w-five:p5', workspace: 'infra-review', agent: 'reviewer', profile: 'personal-default', status: 'idle', unread: false, cost: 0.18, tokens: 1800},
  {id: 'w-six:p6', workspace: 'release-checks', agent: 'worker', profile: 'work-default', status: 'idle', unread: false, cost: 0.09, tokens: 900},
]});
window.edgeNativeReceive('calendar', {status: 'connected', message: 'Apple Calendar / today and tomorrow', updatedAt: now.toISOString(), events: [
  {title: 'Design review', start: later(20), end: later(65), allDay: false},
  {title: 'Lunch with Ada', start: later(120), end: later(180), allDay: false},
  {title: 'Deploy window', start: later(260), end: later(320), allDay: false},
  {title: 'Architecture sync', start: later(380), end: later(440), allDay: false},
  {title: 'Tomorrow planning', start: later(1500), end: later(1560), allDay: false},
]});
window.edgeNativeReceive('weather', {status: 'connected', message: 'Open-Meteo / laptop location', temperature: 18, weatherCode: 2, high: 21, low: 11, days: [
  {date: '2026-09-16', code: 2, high: 21, low: 11},
  {date: '2026-09-17', code: 61, high: 19, low: 12},
  {date: '2026-09-18', code: 0, high: 22, low: 13},
]});
window.edgeNativeReceive('costWindows', {status: 'connected', updatedAt: now.toISOString(), costs: {personal1d: 2.61, personal7d: 8.34, work1d: 0.57, work7d: 1.75}});
window.edgeNativeReceive('brightness', {status: 'connected', message: 'EDGE brightness is ready.', current: 90, original: 95});
window.edgeNativeReceive('temperature', {status: 'connected', message: 'Display-only color temperature is ready.', preset: 'neutral'});
if (params.get('dialog') === 'display') document.querySelector('.display-config').click();
JS

python3 - "$out/index.html" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
html = path.read_text()
needle = '<script src="app.js" defer></script>'
replacement = '<script src="native-shim.js" defer></script><script src="app.js" defer></script><script src="fixture.js" defer></script>'
if html.count(needle) != 1:
    raise SystemExit('expected one app.js script tag')
path.write_text(html.replace(needle, replacement))
PY

for theme in observatory piggy-pink sea-glass ember paper; do
  "$chrome" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=2560,720 --screenshot="$out/$theme.png" \
    "file://$out/index.html?theme=$theme" >/dev/null 2>&1
  printf 'Rendered %s\n' "$out/$theme.png"
done

"$chrome" --headless=new --disable-gpu --hide-scrollbars \
  --window-size=2560,720 --screenshot="$out/display-dialog.png" \
  "file://$out/index.html?theme=observatory&dialog=display" >/dev/null 2>&1
printf 'Rendered %s\n' "$out/display-dialog.png"
