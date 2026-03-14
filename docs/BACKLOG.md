# Backlog

> Estimated, prioritized work items. Add new items at the top of the relevant section.

## Format

Each item: `- [priority] [effort] description (source)`

Priority: `P0` critical, `P1` high, `P2` medium, `P3` low.
Effort: `XS` <1h, `S` 1-4h, `M` half day, `L` 1-2 days, `XL` 3+ days.

---

## Open

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
