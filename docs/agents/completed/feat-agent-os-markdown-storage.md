# feat-agent-os-markdown-storage

> Make Agent OS structured state use LunarOS OKF Markdown/frontmatter instead of thread JSONL.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`/agent-os thread` reads `workspace/.lifeos/db/threads.jsonl`, but LunarOS now stores canonical threads as OKF Markdown under `workspace/threads/<slug>/README.md`. The JSONL thread store is empty, so thread discovery and every command built on the structured store see no threads.

Operational lifecycle and mailbox JSONL files are separate transport/journal concerns and remain unchanged.

## Plan

### Scope

- Agent OS extension storage, thread picker, thread/capture/focus/render/reconcile commands, and generated Markdown views.
- Tests for Markdown parsing, discovery, writes, capture, and rendered output.
- Do not migrate lifecycle event or mailbox transport JSONL.

### Approach

1. Add a small OKF Markdown adapter that scans thread and record documents, parses frontmatter, preserves Markdown bodies, and writes files atomically.
2. Make thread discovery, selection, creation, capture, focus, render, and reconcile use Markdown documents as the authority.
3. Keep lifecycle and mailbox JSONL operational logs intact; remove structured thread JSONL reads/writes and legacy `thread-map` requirements from the active path.
4. Validate against the existing LunarOS Markdown threads and extension tests, then run repository structure/flake/sync checks.

### Risks

- Existing LunarOS frontmatter uses canonical `type: Thread`, kind, stage, and status values that differ from the old JSONL schema.
- Existing Markdown bodies and generated sections must not be overwritten.
- The extension also serves `lifeOS`; the adapter must tolerate an empty or partially migrated workspace without recreating JSONL state.

## Testing

Commands run to validate:

```sh
node --experimental-transform-types --import ./agents/packages/pi-subagents/test/support/register-loader.mjs --test agents/targets/pi/extensions/agent-os/tests/*.test.mjs
node --experimental-transform-types --check agents/targets/pi/extensions/agent-os/core/markdown-store.ts
node --experimental-transform-types --check agents/targets/pi/extensions/agent-os/commands/thread.ts
node --experimental-transform-types --check agents/targets/pi/extensions/agent-os/commands/capture.ts
git diff --check
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
```

All 19 focused tests passed; syntax, diff, structure, flake, and sync checks passed. The live synced LunarOS profile discovered all 11 existing Markdown threads.

## Summary

### What changed

- Added a bounded OKF Markdown/frontmatter adapter for thread and record discovery, atomic creation, and body-preserving updates.
- Migrated thread picker/selection/new-thread/capture/focus/render/reconcile paths off structured thread JSONL and legacy `thread-map`.
- Kept lifecycle event and mailbox JSONL paths unchanged.

### What was tested

- Added adapter and command-path coverage for canonical discovery, body preservation, Markdown writes, no `threads.jsonl`, focus records, and safe reconciliation.
- Ran 19 extension tests plus syntax, diff, structure, flake, and sync checks successfully.

### Follow-up

- No follow-up required for this migration. Keep graph relationships as Markdown links rather than reintroducing an edge store.
