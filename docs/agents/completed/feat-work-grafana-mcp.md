# feat-work-grafana-mcp

> Add the Grafana remote MCP to work agent profiles and generated Pi settings.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Work agents need access to the Grafana MCP hosted at `https://mcp-grafana.lunar.tech/mcp`. The server must be available only through the work profile and must start lazily in generated Pi settings.

## Plan

### Scope

- `agents/defs/mcps/grafana.nix`
- `agents/presets/default.nix`
- `agents/presets/profiles.nix`
- `agents/base-settings.nix`

### Approach

1. Define the remote Grafana MCP server.
2. Import it through the default preset and allow it only in `work-default`.
3. Add the remote server to generated work Pi MCP settings with lazy lifecycle.
4. Run formatting, structure, flake, and sync validations.

### Risks

- The remote Grafana endpoint may require runtime authentication not represented in the requested MCP definition.
- Pi settings are generated from `agents/base-settings.nix`; a local installation needs `sync-agents` to refresh generated files.

## Testing

Commands run to validate:

```sh
nixfmt agents/defs/mcps/grafana.nix agents/presets/default.nix agents/presets/profiles.nix agents/base-settings.nix
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents -- --dry-run
nix run .#sync-agents
```

## Summary

### What changed

- Added the Grafana remote MCP definition and imported it through the default preset.
- Added `grafana` only to the `work-default` MCP membership.
- Added Grafana to generated work Pi MCP settings with `lifecycle = "lazy"`.

### What was tested

- `nixfmt` completed for all four changed Nix files.
- `./scripts/check-structure.sh` passed.
- `nix flake check --no-build` passed after temporarily staging the new definition for flake visibility; it was unstaged afterward.
- `nix run .#sync-agents -- --dry-run` passed and reported no files changed.
- `nix run .#sync-agents` completed; generated work Pi MCP JSON contains Grafana and personal Pi MCP JSON does not.
- Generated Pi MCP JSON evaluated successfully and contains Grafana's requested URL with `lifecycle = "lazy"`.
- Final `git diff --check` passed; no files are staged.

### Follow-up

- None.
