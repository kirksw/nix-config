#!/usr/bin/env bash
set -euo pipefail

if [[ "${PI_CODING_AGENT_DIR:-}" != */bases/personal-browser/profiles/personal-browser ]]; then
  echo "AFFiNE is available only in Pi's home browser profile." >&2
  exit 1
fi
if [[ -z "${AFFINE_MCP_HTTP_TOKEN:-}" ]]; then
  : "${AFFINE_MCP_SOPS_FILE:?Missing home-browser AFFiNE secret configuration}"
  AFFINE_MCP_HTTP_TOKEN="$(sops --decrypt --extract '["token"]' "$AFFINE_MCP_SOPS_FILE")"
  export AFFINE_MCP_HTTP_TOKEN
fi
exec node "$PI_CODING_AGENT_DIR/skills/home-mcp/scripts/run.mjs" affine "$@"
