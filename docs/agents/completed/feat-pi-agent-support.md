# feat-pi-agent-support

> Add pi subagent support and extend sync-agents to sync both OpenCode and pi assets.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The repository already managed OpenCode agents and skills plus a `sync-agents` app that synced
to `~/.config/opencode`. Pi was installed, but there was no equivalent setup for pi agents,
extensions, and prompts. The goal was to support the same named agent roster in pi and keep a
single sync command for both ecosystems.

## Plan

### Scope

- `flake/apps.nix` -- extend `sync-agents` to sync both OpenCode and pi targets.
- `agents/pi/agents/` -- pi-compatible agent definitions with existing names.
- `agents/pi/extensions/subagent/` -- subagent extension for delegated execution.
- `agents/pi/prompts/` -- reusable chain workflows.
- `README.md` -- document expanded sync behavior.

### Approach

1. Keep OpenCode assets unchanged and add pi-specific assets under `agents/pi/`.
2. Extend `sync-agents` to copy:
   - OpenCode agents + skills into `~/.config/opencode/`.
   - Pi agents + shared skills + extensions + prompts into `~/.pi/agent/`.
3. Add pi subagent extension and agent markdown files that preserve the existing names:
   `10xBEAST`, `code-monkey`, `the-architect`, `bottleneck`, `chaos-demon`, `code-red`, `scribe`.
4. Add workflow prompts for chain execution patterns.
5. Validate by evaluating app output and running sync.

### Risks

- Pi and OpenCode frontmatter formats differ, so assets must remain separated.
- Pi extension compatibility may drift with upstream; vendored extension may need periodic refresh.

## Testing

```sh
nix eval --raw .#apps.aarch64-darwin.sync-agents.program
nix run .#sync-agents
```

## Summary

### What changed

- Extended `sync-agents` in `flake/apps.nix` to sync both OpenCode and pi:
  - OpenCode: `~/.config/opencode/{agents,skills}`
  - Pi: `~/.pi/agent/{agents,skills,extensions,prompts}`
- Added pi subagent extension files:
  - `agents/pi/extensions/subagent/index.ts`
  - `agents/pi/extensions/subagent/agents.ts`
- Added pi agent definitions with existing names:
  - `agents/pi/agents/10xBEAST.md`
  - `agents/pi/agents/code-monkey.md`
  - `agents/pi/agents/the-architect.md`
  - `agents/pi/agents/bottleneck.md`
  - `agents/pi/agents/chaos-demon.md`
  - `agents/pi/agents/code-red.md`
  - `agents/pi/agents/scribe.md`
- Added pi prompts:
  - `agents/pi/prompts/implement.md`
  - `agents/pi/prompts/scout-and-plan.md`
  - `agents/pi/prompts/implement-and-review.md`
- Updated `README.md` daily command text to reflect dual sync behavior.

### What was tested

- `nix eval --raw .#apps.aarch64-darwin.sync-agents.program` evaluated successfully.
- `nix run .#sync-agents` copied assets to both OpenCode and pi config directories.

### Follow-up

- P2 S Add a small validator script for pi agent frontmatter (`name`, `description`, optional `tools/model`) to catch malformed agent files early.
- P2 S Add optional cleanup mode to `sync-agents` to remove stale target files no longer present in repo.
