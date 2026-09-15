#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
app="$HOME/Applications/EDGE Calendar.app"
mkdir -p "$app/Contents/MacOS"
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist" >/dev/null 2>&1 || python3 - "$app/Contents/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as f:
    plistlib.dump({
        'CFBundleIdentifier': 'local.edge-dashboard.calendar',
        'CFBundleName': 'EDGE Calendar',
        'CFBundleExecutable': 'edge-calendar',
        'CFBundlePackageType': 'APPL',
        'LSUIElement': True,
        'NSCalendarsFullAccessUsageDescription': 'Display titles and times from your selected calendar on the local EDGE dashboard. No events are modified.',
    }, f)
PY
xcrun swiftc "$root/config/edge-dashboard/calendar.swift" -o "$app/Contents/MacOS/edge-calendar" -framework AppKit -framework EventKit
codesign --force --sign - "$app"
open "$app"
