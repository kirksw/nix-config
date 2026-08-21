#!/usr/bin/env bash
set -euo pipefail

mlx_dspark="${1:-mlx-dspark}"
curl_bin="${CURL_BIN:-curl}"
jq_bin="${JQ_BIN:-jq}"
port="${MLX_DSPARK_CHECK_PORT:-$((20000 + ($$ % 20000)))}"
tmpdir="$(mktemp -d)"
pid=""

cleanup() {
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM

"$mlx_dspark" serve \
  --no-model \
  --host 127.0.0.1 \
  --port "$port" \
  >"$tmpdir/server.log" 2>&1 &
pid=$!

for _ in $(seq 1 60); do
  status="$($curl_bin -sS -o "$tmpdir/health.json" -w '%{http_code}' "http://127.0.0.1:$port/health" || true)"
  if [[ "$status" == 200 ]]; then
    break
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    cat "$tmpdir/server.log" >&2
    exit 1
  fi
  sleep 1
done

$jq_bin -e '.status == "no_model" and .model == null' "$tmpdir/health.json" >/dev/null
models_status="$($curl_bin -sS -o "$tmpdir/models.json" -w '%{http_code}' "http://127.0.0.1:$port/v1/models")"
[[ "$models_status" == 503 ]]
$jq_bin -e '.error != null' "$tmpdir/models.json" >/dev/null

echo "mlx-dspark no-model API check passed"
