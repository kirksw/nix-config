#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
app="$HOME/Applications/EDGE Observatory.app"
if pgrep -f '^/Users/[^/]+/Applications/EDGE Observatory.app/Contents/MacOS/EDGE Observatory$' >/dev/null; then
  printf 'Quit EDGE Observatory before rebuilding it.\n' >&2
  exit 1
fi
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/edge-observatory.XXXXXX")"
bundle="$tmp_root/EDGE Observatory.app"
backup="$tmp_root/previous.app"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
clang -fobjc-arc -Wall -Wextra -Wpedantic -c "$root/packages/edge-observatory/TouchRuntime.m" -o "$tmp_root/TouchRuntime.o" \
  -framework AppKit -framework ApplicationServices -framework IOKit -framework Foundation
xcrun swiftc "$root/packages/edge-observatory/EdgeObservatory.swift" "$root/packages/edge-observatory/XeneonDdc.swift" "$root/packages/edge-observatory/XeneonGamma.swift" \
  "$root/packages/edge-observatory/UnreadTracker.swift" "$root/packages/edge-observatory/ProcessRunner.swift" "$root/packages/edge-observatory/SnapshotModel.swift" "$tmp_root/TouchRuntime.o" \
  -o "$bundle/Contents/MacOS/EDGE Observatory" -framework AppKit -framework EventKit -framework CoreLocation -framework WebKit
cp "$root/packages/edge-observatory/Info.plist" "$bundle/Contents/Info.plist"
cp "$root/packages/edge-observatory/"{index.html,style.css,app.js,TOUCH-LICENSE} "$bundle/Contents/Resources/"
# Sign with the stable self-signed identity so macOS TCC grants (Input Monitoring,
# Accessibility) survive rebuilds. Fall back to ad-hoc only if the identity is gone.
sign_identity="EDGE Observatory Development"
if ! security find-identity -v -p codesigning | grep -q "EDGE Observatory Development"; then
  sign_identity="-"
fi
codesign --force --deep --sign "$sign_identity" "$bundle"
mkdir -p "$HOME/Applications"
if [[ -e "$app" ]]; then mv "$app" "$backup"; fi
if ! mv "$bundle" "$app"; then
  rm -rf "$app"
  [[ -e "$backup" ]] && mv "$backup" "$app"
  exit 1
fi
rm -rf "$backup"
printf 'Built %s\n' "$app"
