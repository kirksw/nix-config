# Backlog

> Estimated, prioritized work items. Add new items at the top of the relevant section.

## Format

Each item: `- [priority] [effort] description (source)`

Priority: `P0` critical, `P1` high, `P2` medium, `P3` low.
Effort: `XS` <1h, `S` 1-4h, `M` half day, `L` 1-2 days, `XL` 3+ days.

---

## Open

- P1 XS Run one final Darwin switch to install syncMode-aware wrappers on `lunar` (feat-wrapper-sync-mode)
- P2 XS Merge nix-agents `feat/wrapper-sync-mode` upstream and point the flake input back to default branch (feat-wrapper-sync-mode)
- P2 XS Add or document the missing `sync-agents` flake app referenced by the agent workflow (feat-pi-session-dir)
- P2 S Upstream nix-agents Pi wrapper fix so generated profile sync never deletes or copies live session directories (feat-pi-session-dir)
- P1 M Slim upstream `nix-agents` to engine/templates only after local config migration is stable (feat-local-agent-config)
- P2 S Re-enable profile sandbox policy after upstream `nix-agents` publishes the `sandboxes` module API (feat-local-agent-config)
- P2 XS Manually smoke-test PI todo extension in interactive session (`/todos`, branch switch/fork replay) (feat-pi-todo-extension)
- P2 S Add frontmatter/schema validator for Claude/Cursor/Codex agent assets (feat-multi-platform-agent-support)
- P2 S Add pi agent frontmatter validator to check `name`/`description`/`tools` consistency (feat-pi-agent-support)
- P2 S Automate agent sync via home-manager activation instead of manual `nix run .#sync-agents` (feat-initial-agents)
- P2 XS Add `steps` limits to subagents for cost control (feat-initial-agents)
- P2 S Tighten `mid-engineer` bash permissions to deny destructive commands (feat-initial-agents)
- P3 S Upstream skill-creator is vendored; add update script or flake input (feat-initial-agents)
- P2 S Review and update module documentation as needed (legacy backlog)
- P3 S Add example for creating new custom package (legacy backlog)

## Done

_Move items here when completed, with date._

- 2026-06-09 P2 S Teach installed nix-agents wrappers to prefer a mutable `sync-agents` generation so stale wrappers do not overwrite manual sync output (feat-wrapper-sync-mode)
