# feat-multi-platform-agent-support

> Extend agent/skill support from OpenCode+pi to Claude, Cursor, and Codex CLI with one sync command.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The repo already synced OpenCode and pi assets, but the same agent roster and shared skills were
not available in Claude Code, Cursor Agent, and Codex CLI. The goal is to keep a single source of
truth in this repository and a single sync command that provisions all supported agent runtimes.

## Plan

### Scope

- `flake/apps.nix` -- extend `sync-agents` to include Claude, Cursor, and Codex targets.
- `agents/claude/` -- Claude-specific agent definitions and guidance.
- `agents/cursor/` -- Cursor-specific agent definitions and guidance.
- `agents/codex/` -- Codex role configs, AGENTS guidance, and managed `config.toml`.
- `README.md` -- document expanded sync behavior.

### Approach

1. Preserve existing OpenCode and pi flows.
2. Add platform-specific source trees for Claude, Cursor, and Codex.
3. Extend `sync-agents` to copy:
   - Claude: `~/.claude/{agents,skills,CLAUDE.md}`
   - Cursor: `~/.cursor/{agents,skills,AGENTS.md}`
   - Codex: `~/.codex/{agents,skills,AGENTS.md,config.toml}`
4. Make `agents/codex/config.toml` the source-of-truth for `~/.codex/config.toml`.
5. Validate with `nix eval`, `nix run .#sync-agents`, and `nix flake check --no-build`.

### Risks

- Agent frontmatter/schema differs by platform, so definitions must remain platform-specific.
- Codex role configs are strict; invalid or missing role files can prevent role spawning.
- Managing `~/.codex/config.toml` from repo means local manual edits will be overwritten by sync.

## Testing

Commands run to validate:

```sh
nix eval --raw .#apps.aarch64-darwin.sync-agents.program
nix run .#sync-agents
nix flake check --no-build
```

## Summary

### What changed

- Extended `sync-agents` in `flake/apps.nix` to sync five ecosystems from one command:
  - OpenCode: `~/.config/opencode/{agents,skills,AGENTS.md}`
  - Claude: `~/.claude/{agents,skills,CLAUDE.md}`
  - Cursor: `~/.cursor/{agents,skills,AGENTS.md}`
  - Codex: `~/.codex/{agents,skills,AGENTS.md,config.toml}`
  - pi: `~/.pi/agent/{agents,skills,extensions,prompts,AGENTS.md}`
- Added Claude agent sources and workflow guide:
  - `agents/claude/CLAUDE.md`
  - `agents/claude/agents/{10xBEAST,bottleneck,chaos-demon,code-monkey,code-red,scribe,the-architect}.md`
- Added Cursor agent sources and workflow guide:
  - `agents/cursor/AGENTS.md`
  - `agents/cursor/agents/{10xBEAST,bottleneck,chaos-demon,code-monkey,code-red,scribe,the-architect}.md`
- Added Codex managed assets:
  - `agents/codex/AGENTS.md`
  - `agents/codex/config.toml`
  - `agents/codex/agents/{10xBEAST,code-monkey,the-architect,bottleneck,chaos-demon,code-red,scribe}.toml`
- Updated `README.md` daily command text to reflect expanded multi-platform sync behavior.

### What was tested

- `nix eval --raw .#apps.aarch64-darwin.sync-agents.program`
- `nix run .#sync-agents`
- `nix flake check --no-build`

### Follow-up

- P2 S Add frontmatter/schema validation for Claude/Cursor/Codex agent assets to catch malformed files before sync.
- P2 S Add optional prune mode to `sync-agents` for Claude/Cursor/Codex targets to remove stale files.
