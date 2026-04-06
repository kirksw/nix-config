# feat-work-agent-api-keys

> Expose both Lunar OpenAI and Anthropic credentials to OpenCode and Pi in work directories.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The work-profile wrappers for `opencode` and `pi` currently only expose the Lunar OpenAI key.
For work repositories under `~/git/github.com/lunarway`, both tools should also receive the
Anthropic/Claude credential so either provider can be used without manual shell setup.

## Plan

### Scope

- `modules/home/programs/opencode.nix`
- `modules/home/programs/pi-coding-agent.nix`
- `docs/agents/feat-work-agent-api-keys.md`

### Approach

1. Add the Lunar Anthropic secret reference to both modules.
2. Export both OpenAI and Anthropic credentials in work-directory wrappers.
3. Extend the OpenCode work profile config to expose an Anthropic provider entry.
4. Validate with `nix flake check --no-build`.

### Risks

- This assumes `secrets/api/lunar.yaml` key `anthropic` is the credential OpenCode and Pi should
  consume as `ANTHROPIC_API_KEY`.

## Testing

Commands run to validate:

```sh
nix flake check --no-build
```

## Summary

### What changed

- Updated `modules/home/programs/opencode.nix` to expose both Lunar OpenAI and
  Anthropic credentials in work directories.
- Added an Anthropic provider entry to the OpenCode work profile config.
- Updated `modules/home/programs/pi-coding-agent.nix` to expose both Lunar
  OpenAI and Anthropic credentials in work directories.
- Added the `api/lunar/anthropic` SOPS secret reference to both modules.

### What was tested

- `nix flake check --no-build`

### Follow-up

- None.
