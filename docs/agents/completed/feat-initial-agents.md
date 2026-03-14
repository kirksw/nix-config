# feat-initial-agents

> Add OpenCode subagents, skill-creator, and sync-agents flake app.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The repository had no OpenCode agent definitions or skills. We needed a set of
specialized subagents for different engineering roles (architecture, implementation,
review, security) and a way to sync them into the local OpenCode config.

## Plan

### Scope

- `agents/agents/` -- 5 new subagent markdown files.
- `agents/skills/skill-creator/` -- imported from anthropics/skills.
- `flake/apps.nix` -- new `sync-agents` flake app.
- `README.md` -- document `nix run .#sync-agents`.

### Approach

1. Create agent definitions as OpenCode markdown agents.
2. Configure per-agent models, permissions, and prompts.
3. Import anthropics skill-creator for future skill generation.
4. Add `nix run .#sync-agents` to copy `agents/` into `~/.config/opencode/`.

### Risks

- Permission allowlists may need tuning as OpenCode evolves.
- Upstream skill-creator is vendored; manual updates required.

## Testing

```sh
nix eval --raw .#apps.aarch64-darwin.sync-agents.program  # evaluates successfully
nix run .#sync-agents                                      # copies to ~/.config/opencode
```

## Summary

### What changed

- Added 5 subagents:
  - `architect` (openai/gpt-5.2) -- architecture/design, markdown-only edits.
  - `staff-engineer` (anthropic/claude-opus-4-6) -- full implementation.
  - `mid-engineer` (anthropic/claude-sonnet-4-5) -- simpler tasks, escalates to staff.
  - `reviewer` (openai/gpt-5.3-codex) -- read-only code review with git/rg allowlist.
  - `vulnerability` (openai/gpt-5.3-codex) -- read-only security audit with static check allowlist.
- Imported `agents/skills/skill-creator/` from anthropics/skills.
- Added `sync-agents` flake app and documented it in README.

### What was tested

- `nix eval` confirmed the flake app evaluates.
- `nix run .#sync-agents` confirmed files sync to `~/.config/opencode/`.

### Follow-up

Items added to `docs/BACKLOG.md`:
- P2 S Automate agent sync via home-manager activation.
- P2 XS Add `steps` limits to subagents for cost control.
- P2 S Tighten `mid-engineer` bash permissions.
- P3 S Vendor update script for skill-creator.
