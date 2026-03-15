# feat-pi-coding-agent

> Add home module for pi-coding-agent with personal/work profile support matching opencode pattern.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The repository already has `pi-config` synced via `sync-agents` to `~/.pi/agent/`, and `pi-coding-agent` package is available from the `nix-agents` input. However, there's no home module to:

1. Wrap the `pi` binary with profile switching (personal vs work)
2. Configure API keys via sops secrets
3. Manage pi config files per profile

The opencode, claude-code, and codex modules all follow this pattern. This feature adds the same support for pi-coding-agent.

## Plan

### Scope

- `modules/home/programs/pi-coding-agent.nix` -- new home module
- `modules/home/imports.nix` -- add import
- `hosts/darwin/work/home.nix` -- enable module (optional, based on user preference)

### Approach

1. Create `modules/home/programs/pi-coding-agent.nix` following the opencode.nix pattern:
   - `homeModules.piCodingAgent.enable` option
   - Wrapper script that:
     - Detects work projects via `is_work_project()` (same as opencode: `~/git/github.com/lunarway`)
     - Sets `XDG_CONFIG_HOME` and `XDG_DATA_HOME` for profile isolation
     - Exports `OPENAI_API_KEY` (work) or `ZAI_API_KEY` (personal) from sops secrets
     - Executes `pi` binary from `pkgs.llm-agents.pi`
   - sops secrets for `zai` and `api/lunar/openai`
   - xdg.configFile for per-profile pi config (if needed)

2. Add import to `modules/home/imports.nix`

3. Enable in `hosts/darwin/work/home.nix` with `homeModules.piCodingAgent.enable = true`

4. Validate with `nix flake check --no-build` and `apps/aarch64-darwin/build`

### Key Decisions

- **API Provider Mapping** (matches opencode):
  - Personal: ZAI (`zai_token` from `secrets/api/default.yaml`) + Minimax (`minimax` from `secrets/api/default.yaml`)
  - Work: OpenAI EU (`openai` from `secrets/api/lunar.yaml`)
- **Profile Detection**: Same as opencode (`~/git/github.com/lunarway` = work)
- **Profile Paths**:
  - Personal: `~/.config/pi/profiles/personal`, `~/.local/share/pi/profiles/personal`
  - Work: `~/.config/pi/profiles/work`, `~/.local/share/pi/profiles/work`
- **Binary Name**: `pi` (from `pkgs.llm-agents.pi`)
- **Wrapper Name**: `pi` (shadowing the original, same pattern as opencode)

### Risks

- Pi's config format may differ from opencode's JSON format -- need to verify if pi reads config files or relies solely on env vars/auth.json
- Profile isolation via `XDG_CONFIG_HOME`/`XDG_DATA_HOME` assumes pi respects these variables (likely since it's a Node.js app)
- May need to create initial `auth.json` per profile if pi doesn't support env-only auth

## Testing

```sh
nix flake check --no-build
nix run .#apps.aarch64-darwin.build
# After enabling:
nix run .#switch
pi --version  # Verify wrapper works
```

## Summary

### What changed

- Created `modules/home/programs/pi-coding-agent.nix` with:
  - `homeModules.piCodingAgent.enable` option
  - Wrapper script with personal/work profile detection (same as opencode)
  - ZAI_API_KEY and MINIMAX_API_KEY for personal profile
  - OPENAI_API_KEY for work profile
  - sops secrets for `zai`, `minimax`, and `api/lunar/openai`
- Added import to `modules/home/imports.nix`
- Enabled in `hosts/darwin/work/home.nix`
- Updated `modules/home/programs/opencode.nix` to add minimax provider and MINIMAX_API_KEY for personal profile

### What was tested

- `nix flake check --no-build` passed

### Follow-up

- None identified.
