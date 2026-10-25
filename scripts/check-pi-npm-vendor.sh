#!/usr/bin/env bash
# Regression test for the pi-npm-vendor tool, which must be fail-closed: Pi
# profiles never fall back to startup npm installs. Covers fresh-setup
# publishing, update semantics, npm failure preserving the previous usable
# generation, incomplete verification, invalid settings, dry-run, and the
# no-deletion guarantee. Runs fully offline through the stub npm command.
set -euo pipefail

vendor="${1:-pi-npm-vendor}"
stub_npm="${2:-$(dirname "$0")/pi-npm-stub.sh}"
jq_bin="${JQ_BIN:-jq}"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

export XDG_CONFIG_HOME="$tmpdir/config"
export HOME="$tmpdir/home"
export PI_NPM_TIMEOUT_SECS=30
export PI_NPM_BIN="$(cd "$(dirname "$stub_npm")" && pwd)/$(basename "$stub_npm")"
config_base="$XDG_CONFIG_HOME/nix-agents"
mkdir -p "$HOME" "$config_base"

manifest_path="$("$vendor" --manifest)"
if [ ! -r "$manifest_path" ]; then
  echo "check-pi-npm-vendor: cannot read vendor manifest: $manifest_path" >&2
  exit 1
fi

npm_log="$tmpdir/npm-calls.log"
: > "$npm_log"
export PI_NPM_CALL_LOG="$npm_log"
export npm_log

assert_jq() {
  file="$1"
  expected="$2"
  expr="$3"
  root="${4:-}"
  actual="$("$jq_bin" -r --arg root "$root" "$expr" "$file")"
  if [ "$actual" != "$expected" ]; then
    echo "check-pi-npm-vendor: assertion failed: $expr" >&2
    echo "  file:     $file" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
}

assert_vendor_fails() {
  set +e
  "$vendor" --strict >"$tmpdir/fail.out" 2>"$tmpdir/fail.err"
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    echo "check-pi-npm-vendor: expected non-zero exit: $*" >&2
    cat "$tmpdir/fail.out" "$tmpdir/fail.err" >&2
    exit 1
  fi
  if grep -q "pi-npm-vendor: complete" "$tmpdir/fail.out"; then
    echo "check-pi-npm-vendor: failed run must not claim completion" >&2
    exit 1
  fi
}

set_root_of() {
  ls -d "$config_base/pi/npm/$1"/set-* 2>/dev/null | head -1
}

npm_calls_for() {
  grep -c -F -- "--prefix $1" "$npm_log" || true
}

settings_of() {
  printf '%s\n' "$config_base/pi/bases/$1/settings/settings.json"
}

echo "== 1. fresh setup publishes settings with vendored paths"
personal_settings="$(settings_of personal-default)"
test ! -e "$personal_settings"
"$vendor" --strict >"$tmpdir/run1.out" 2>&1
personal_set="$(set_root_of personal-default)"
assert_jq "$personal_settings" "$personal_set/node_modules/pi-cost" '.packages[0]'
assert_jq "$personal_settings" "0" \
  '[.packages[] | (if type == "object" then .source else . end) | select(startswith("npm:"))] | length'
assert_jq "$personal_settings" "true" \
  'any(.packages[]; type == "string" and endswith("/agents/packages/pi-todo"))'
assert_jq "$personal_settings" "rose-pine" '.theme'
assert_jq "$personal_settings" "litellm" '.defaultProvider'
assert_jq "$personal_settings" "openai/gpt-6-sol" '.defaultModel'
assert_jq "$personal_settings" "absent" '(.npmCommand // "absent")'
test -f "$personal_set/node_modules/@plannotator/pi-extension/package.json"
test -f "$personal_set/.gitignore"
assert_jq "$personal_set/package.json" "0.1.1" '.dependencies["pi-cost"]'
assert_jq "$personal_set/vendor-manifest.json" "0.1.1" '.["pi-cost"].version'
[ "$(npm_calls_for "$personal_set")" -eq 1 ]

echo "== 2. warm set: no npm call, settings unchanged"
cp "$personal_settings" "$tmpdir/settings-before"
"$vendor" --strict >/dev/null 2>&1
[ "$(npm_calls_for "$personal_set")" -eq 1 ]
"$jq_bin" -e --slurpfile before "$tmpdir/settings-before" '. == $before[0]' "$personal_settings" >/dev/null

echo "== 3. work bases keep npmCommand; context-decisions is work-only"
work_settings="$(settings_of work-default)"
work_set="$(set_root_of work-default)"
assert_jq "$work_settings" "1" '.npmCommand | length'
assert_jq "$work_settings" "true" '.npmCommand[0] | endswith("/bin/pi-npm")'
assert_jq "$work_settings" "true" \
  'any(.packages[]; type == "string" and . == ($root + "/node_modules/pi-context-decisions"))' "$work_set"
assert_jq "$work_settings" "true" \
  'any(.packages[]; type == "string" and . == ($root + "/node_modules/@lunarway/pi-lunar-litellm"))' "$work_set"
fallback_settings="$(settings_of work)"
fallback_set="$(set_root_of work)"
assert_jq "$fallback_settings" "false" \
  'any(.packages[]; (if type == "object" then .source else . end) | contains("pi-context-decisions"))'
assert_jq "$fallback_settings" "0" \
  '[.packages[] | (if type == "object" then .source else . end) | select(startswith("npm:"))] | length'
assert_jq "$fallback_settings" "2" \
  '[.packages[] | select(type == "string" and startswith($root))] | length' "$fallback_set"
assert_jq "$personal_settings" "false" \
  'any(.packages[]; (if type == "object" then .source else . end) | contains("pi-context-decisions"))'

echo "== 4. updates preserve runtime keys and replace package selections"
"$jq_bin" '.runtimeOnlyKey = {kept: true} | .lastChangelogVersion = "9.9.9"
  | .packages += ["npm:pi-user-added@1.0.0"]' "$personal_settings" > "$personal_settings.next"
mv "$personal_settings.next" "$personal_settings"
rm -rf "$personal_set/node_modules/pi-web-access"
"$vendor" --strict >/dev/null 2>&1
assert_jq "$personal_settings" "true" '.runtimeOnlyKey.kept'
assert_jq "$personal_settings" "9.9.9" '.lastChangelogVersion'
assert_jq "$personal_settings" "0" \
  '[.packages[] | (if type == "object" then .source else . end) | select(startswith("npm:"))] | length'
assert_jq "$personal_settings" "true" \
  'any(.packages[]; type == "string" and . == ($root + "/node_modules/pi-web-access"))' "$personal_set"

echo "== 5. failed new-generation build preserves the previous usable settings"
old_set="$config_base/pi/npm/personal-default/set-old0set0dir0"
cp -R "$personal_set" "$old_set"
"$jq_bin" --arg cur "$personal_set" --arg old "$old_set" \
  'map(if type == "object" then (.source |= sub($cur; $old)) else sub($cur; $old) end)' \
  <<<"$("$jq_bin" '.packages' "$personal_settings")" > "$tmpdir/old-packages.json"
"$jq_bin" --slurpfile pkgs "$tmpdir/old-packages.json" '.packages = $pkgs[0]' \
  "$personal_settings" > "$tmpdir/old-settings.json"
cp "$tmpdir/old-settings.json" "$personal_settings"
rm -rf "$personal_set/node_modules/pi-cost"
FAIL_NEXT_INSTALL=1 assert_vendor_fails "npm failure must fail the run"
grep -q "npm install failed" "$tmpdir/fail.err"
"$jq_bin" -e --slurpfile before "$tmpdir/old-settings.json" '. == $before[0]' "$personal_settings" >/dev/null
test -f "$old_set/node_modules/pi-cost/package.json"

echo "== 6. incomplete verification fails without publishing"
PI_OFFLINE=1 assert_vendor_fails "offline incomplete set must fail"
grep -q "vendoring incomplete" "$tmpdir/fail.err"
grep -q "refusing to publish" "$tmpdir/fail.err"
"$jq_bin" -e --slurpfile before "$tmpdir/old-settings.json" '. == $before[0]' "$personal_settings" >/dev/null

echo "== 7. invalid settings fail the run untouched"
browser_settings="$(settings_of work-browser)"
mkdir -p "$(dirname "$browser_settings")"
printf 'not-json{\n' > "$browser_settings"
cp "$browser_settings" "$tmpdir/invalid-before"
assert_vendor_fails "invalid settings must fail the run"
cmp -s "$browser_settings" "$tmpdir/invalid-before"
grep -q "not valid JSON" "$tmpdir/fail.err"

echo "== 8. dry-run installs and publishes nothing"
rm -f "$browser_settings"
"$vendor" --strict >/dev/null 2>&1
pb_settings="$(settings_of personal-browser)"
rm -f "$pb_settings"
calls_before="$(wc -l < "$npm_log" | tr -d ' ')"
"$vendor" --dry-run >"$tmpdir/dry.out" 2>&1
test ! -e "$pb_settings"
grep -q "DRY-RUN would publish" "$tmpdir/dry.out"
[ "$(wc -l < "$npm_log" | tr -d ' ')" -eq "$calls_before" ]

echo "== 9. nothing under the npm root is ever deleted"
stray="$config_base/pi/npm/personal-browser/set-stray0000000"
mkdir -p "$stray"
"$vendor" --strict >/dev/null 2>&1
test -d "$stray"
test -d "$old_set"

echo "== 10. healthy machine completes"
"$vendor" --strict >"$tmpdir/final.out" 2>&1
grep -q "pi-npm-vendor: complete" "$tmpdir/final.out"
for base in personal personal-browser personal-default work work-browser work-default; do
  settings="$(settings_of "$base")"
  test -f "$settings"
  assert_jq "$settings" "0" \
    '[.packages[] | (if type == "object" then .source else . end) | select(startswith("npm:"))] | length'
done

echo "check-pi-npm-vendor: all vendoring regression assertions passed"
