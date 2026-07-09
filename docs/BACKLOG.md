# Backlog

> Estimated, prioritized work items. Add new items at the top of the relevant section.

## Format

Each item: `- [priority] [effort] description (source)`

Priority: `P0` critical, `P1` high, `P2` medium, `P3` low.
Effort: `XS` <1h, `S` 1-4h, `M` half day, `L` 1-2 days, `XL` 3+ days.

---

## Open

- P2 XS Revoke the former Kirk and Sanja LLM-router API keys after direct MiniMax/ZAI traffic is confirmed (feat-direct-assistant-providers)
- P2 S Add a mechanical knowledge-store check for required indexes, valid local links, and design-document verification metadata (feat-repository-knowledge-store)
- P3 XL Explore dynamic/problem-specific Pi agent assembly: nix-agents builds a full catalog (all agents/skills/extensions/mcps), and a runtime selector reads context from `kirksw/notes` to symlink only the relevant subset into the Pi profile dir before launch. Defers implementation until notes repo has enough structured content to drive problem-aware skill/extension selection (agent-discussion)
- P2 S Upstream pi-kanban configurable session roots and parallel dashboard support, then remove the local vendor patch (feat-pi-kanban-session-aware)
- P1 XS Run Darwin switch and `nix run .#sync-agents` after work MCP mapping lands so live Codex base settings pick up the deduped MCP source of truth (feat-work-sourcegraph-mcp)
- P1 M Bootstrap sandboxed OpenClaw and GitHub/LLM credentials inside `personal-assistant`, `household-assistant`, and `work-assistant` after first boot (feat-agent-microvms)
- P2 S Calibrate `model-bench` agent-binary criteria with harder scout repos and known-good/known-bad outputs (feat-model-bench-agent-verifier)
- P2 M Add a stronger sandbox for `model-bench` code-execution verifiers on macOS/Linux (feat-model-bench review)
- P2 S Teach `model-bench` to import live profile tier mappings from nix-agents metadata as a fallback to `tier-overrides.toml` (feat-model-bench)
- P3 S Add more fixture variants per agent role to reduce overfitting in `model-bench` results (feat-model-bench)
- P1 XS Run one final Darwin switch to install syncMode-aware wrappers on `lunar` (feat-wrapper-sync-mode)
- P2 S Upstream nix-agents Pi wrapper fix so generated profile sync never deletes or copies live session directories (feat-pi-session-dir)
- P1 M Slim upstream `nix-agents` to engine/templates only after local config migration is stable (feat-local-agent-config)
- P2 S Re-enable profile sandbox policy after upstream `nix-agents` publishes the `sandboxes` module API (feat-local-agent-config)
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

- 2026-07-09 P2 XS Confirm `sync-agents` flake app exists and remove the stale missing-app item (repository hygiene)
- 2026-07-09 P2 XS Confirm the flake input points to `nix-agents/main` and remove the stale branch-merge item (repository hygiene)
- 2026-06-09 P2 S Teach installed nix-agents wrappers to prefer a mutable `sync-agents` generation so stale wrappers do not overwrite manual sync output (feat-wrapper-sync-mode)
