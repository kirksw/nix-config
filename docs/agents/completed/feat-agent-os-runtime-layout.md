# feat-agent-os-runtime-layout

> Remove `.lifeos/db` and scope runtime transport to the OS, Thread, and Factory hierarchy.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Agent OS currently stores lifecycle events and mailbox transport under `workspace/.lifeos/db`, while LunarOS canonical state lives directly under `workspace/threads/<thread>/workpackages/<workpackage>`. The hidden database directory is not aligned with the OS/Thread/Factory ownership model.

## Plan

### Scope

- Agent OS mailbox and lifecycle runtime paths.
- OS, Thread, and Factory runtime scope resolution and policy.
- Migration of existing `.lifeos/db` data, including lifecycle events.
- Tests, documentation, and repository validation.

### Approach

1. Define runtime paths that mirror ownership:
   - `workspace/runtime/os/{mailbox,events}.jsonl`
   - `workspace/runtime/threads/<thread>/{mailbox,events}.jsonl`
   - `workspace/runtime/threads/<thread>/workpackages/<workpackage>/{mailbox,events}.jsonl`
2. Route mailbox writes to the recipient scope and reads/acknowledgements to the active scope.
3. Route lifecycle events to the active scope; keep canonical work and decisions in Markdown.
4. Migrate any existing `.lifeos/db` records, then remove `.lifeos/db` references and the directory from the workspace.
5. Validate OS, Thread, and Factory isolation, mailbox routing, migration idempotency, and live synced behavior.

### Risks

- Runtime files are operational JSONL, not canonical knowledge; they must not become a second source of truth.
- Existing `.lifeos/db` may contain records from older implementations; migration must be loss-aware and idempotent.
- Factory paths may be supplied as IDs or paths; runtime scope must normalize them consistently.

## Testing

Commands run to validate:

```sh
node --experimental-transform-types --import ./agents/packages/pi-subagents/test/support/register-loader.mjs --test agents/targets/pi/extensions/agent-os/tests/*.test.mjs
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
```

The focused suite passed all 20 tests. The live LunarOS workspace migration moved 68 lifecycle records into `workspace/runtime/os/events.jsonl`; the LifeOS migration moved its legacy lifecycle and structured records into scoped runtime/Markdown files. Both workspaces have no `.lifeos` directory, and the synced `/agent-os status` session loaded with `unread=0`.

## Summary

### What changed

- Added scoped runtime paths for OS, Thread, and Factory mailbox/events files.
- Routed mailbox writes to recipient scope and reads/acknowledgements to active scope.
- Added idempotent legacy runtime migration with safe removal only after complete success.
- Wired migration at session startup and removed `.lifeos` from the live LunarOS and LifeOS workspaces.

### What was tested

- 20 focused Agent OS tests passed.
- Structure check, flake evaluation, and agent sync passed.
- Live synced LunarOS status loaded successfully; 68 LunarOS lifecycle events and LifeOS legacy records were migrated.

### Follow-up

- Existing legacy structured stores with non-empty unsupported data intentionally remain until explicitly converted; migration reports them instead of deleting them.
