# feat-pi-only

> Make Pi the only agent runtime this repo configures and replace the `nix-agents` engine with local generation.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi is the only interactive agent runtime this repository needs to configure.
The Claude Code, Codex, and OpenCode wrappers existed only because the `nix-agents` engine generated all four targets, so removing them removed the last consumers of the multi-target abstractions.
With one target left and no custom agents, the engine's remaining work for this repository reduced to packaging skill directories, appending a model-tier manifest to `AGENTS.md`, and generating a wrapper. That is small enough to own locally, so the dependency was removed rather than retained.

The raw `claude-code`, `codex`, and `opencode` packages remain installed: omnigent vendors the Claude and Codex binaries.

## Plan

### Scope

- `agents/` — profile data, asset packaging, base settings.
- `flake/apps.nix` — sync and base-settings generation.
- `modules/home/programs/ai-agents.nix` — the `pi` wrapper and `pix` launcher.
- `hosts/darwin/work/home.nix` and `hosts/nixos/ry4a/agent-microvms.nix` — enablement and the microVM launcher.
- `flake.nix`, `flake.lock`, checks, scripts, and documentation.

### Principles

1. **Pi behavior is frozen.** The same three profiles per scope, the same base and authentication scoping, the same session layout, and the same `pi`/`pix` launcher semantics.
2. **Delete, do not shim.** Removed code paths are deleted rather than left behind as disabled options.
3. **Keep the raw packages.** Only the wrappers and generated configuration go.
4. **`agents/` stays the single source of truth.** No manual edits to generated paths.
5. **One code path.** No engine-generated Pi configuration next to a repo-local replacement.

### Approach

1. Add `agents/pi-profiles.nix` (bases, providers, profiles, tier mappings) and `agents/pi-assets.nix` (skill loading, per-profile asset derivation, tier manifest, skill-versions, profile metadata).
2. Make `flake/apps.nix` sync Pi only, using the local profile metadata; drop the Codex config merge, the Claude settings exclusion path, and the Codex image guidance.
3. Rewrite the Pi wrapper without the engine: keep profile selection and browser/session handling, and add provider credential mapping, per-base commit identity, and launch-time asset bootstrap.
4. Remove the `nix-agents` input, delete the dead presets, MCP definitions, hooks, and chains, and update checks and documentation.

### Risks

- **Stale generated directories.** Sync never deletes base directories, so live `claude/`, `codex/`, and `opencode/` trees remain. Tracked in `docs/BACKLOG.md`; deletion needs explicit approval because sessions and authentication live there.
- **Lost generation surface.** Claude permission settings, Claude `.mcp.json`, Codex `config.toml`, and the OpenCode config are no longer generated. Omnigent sets `CODEX_HOME` and `CLAUDE_CONFIG_DIR` itself and vendors the binaries, so it is unaffected.
- **Wrapper drift.** Credential mapping and commit identity are now generated from `agents/pi-profiles.nix`, so a provider or base change needs no wrapper edit.

## Testing

```sh
./scripts/check-structure.sh
nixfmt --check <changed files>
git diff --check
nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link
nix build .#checks.aarch64-darwin.sync-agents-settings-merge --no-link
python3 scripts/check-pi-experimental-launchers.py
nix eval --raw .#darwinConfigurations.lunar.config.system.build.toplevel.drvPath
nix run .#sync-agents
PI_OFFLINE=1 pi list
```

## Definition Of Done

- Only the `pi` target is generated and synced.
- `pi` and `pix` behave as before for `default`, `fallback`, and `browser` in both scopes.
- No `nix-agents` wrapper is installed for Claude Code, Codex, or OpenCode.
- Omnigent and other consumers still resolve the Claude and Codex binaries.
- Targeted checks pass, or blockers are recorded.
- Documentation describes Pi as the only configured target.

## Summary

### What changed

- Replaced the `nix-agents` engine with local generation: `agents/pi-profiles.nix` holds bases, providers, profiles, and tier mappings; `agents/pi-assets.nix` loads skills and builds one store path per profile.
- Made `flake/apps.nix` Pi-only and dropped the Codex config merge, the Claude settings exclusion path, and the Codex image guidance.
- Rewrote the `pi` wrapper without the engine. Profile selection is unchanged; provider credential mapping and per-base commit identity are generated from `agents/pi-profiles.nix`; missing assets and base settings are bootstrapped at launch.
- Removed the `nix-agents` flake input and every reference to it, including the host overlay.
- Removed the Claude Code, OpenCode, and Codex wrappers, their Home Manager options, and their `hosts/darwin/work/home.nix` enables. The raw packages stay for omnigent.
- Deleted the dead surfaces: `agents/presets/`, `agents/defs/mcps/`, `agents/defs/hooks/`, `agents/targets/pi/chains/`, `agents/targets/pi/provider-overrides.nix`, `agents/targets/pi/experimental-profiles.nix`, and the obsolete `docs/nix-agents-engine-config-split.md`.
- Updated `bases-and-profiles.md`, `layout.md`, `source-of-truth.md`, the `add-module` and `nix-agents` skills, `model-tiers.md`, and the `pix` description.

### What was tested

- `./scripts/check-structure.sh`, `nixfmt --check` on every changed file, and `git diff --check`: passed.
- `nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link`: passed.
- `nix build .#checks.aarch64-darwin.sync-agents-settings-merge --no-link`: passed.
- `python3 scripts/check-pi-experimental-launchers.py`: passed.
- `python3 scripts/check-pi-wrapper-chain.py <built pi> <built pix>`: passed for all six profiles after adapting the script to the single-layer wrapper.
- `nix eval .#darwinConfigurations.lunar.config.system.build.toplevel.drvPath`: evaluates.
- `nix run .#sync-agents`: syncs the six Pi profiles only.
- The built wrapper ran in an isolated HOME for `personal-default`, `personal-fallback`, and `personal-browser`; each created the correct base/profile tree with 14, 14, and 5 skills, and `pi --version` returned `0.84.1`.

### Follow-up

- Retire the legacy generated `claude/`, `codex/`, and `opencode/` trees, preserving sessions and authentication. Tracked in `docs/BACKLOG.md`.
- The NixOS `nixos-ry4a` evaluation remains blocked by the pre-existing OpenClaw QMD schema assertion in `hosts/nixos/ry4a/openclaw-assistant.nix`; the microVM guest config and its Pi wrapper derivation evaluate, but the launcher shell was not executed.
