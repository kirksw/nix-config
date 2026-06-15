# feat-thread-os

> Rename the LifeOS Pi extension to thread-os and route personal/work activity to separate lifeOS and lunarOS repos.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`lifeOS` and `lunarOS` are now separate durable-memory repos: personal project management belongs in `lifeOS`, and Lunar/work project management belongs in `lunarOS`. The current Pi extension and session hook are still LifeOS-branded and assume one repo for both scopes. They need a neutral command surface and split repo routing.

## Plan

### Scope

- `agents/targets/pi/extensions/lifeos/` → renamed to `agents/targets/pi/extensions/thread-os/`
- `agents/defs/hooks/session-write.nix`
- `docs/agents/completed/feat-lifeos-pi-extension-v0.md`
- `docs/agents/completed/feat-lifeos-session-hook.md`
- `docs/BACKLOG.md`
- `docs/agents/feat-thread-os.md`

### Approach

1. Rename the Pi extension directory and command surface from `lifeos` to `thread-os`.
2. Update repo resolution so personal contexts use `lifeOS` and work contexts use `lunarOS`, with env overrides via `THREAD_OS_PERSONAL_REPO` and `THREAD_OS_WORK_REPO`.
3. Update command output/help/docs from LifeOS wording to Thread OS wording, while preserving the existing on-disk JSONL/db layout unless a rename is required.
4. Update the session-end hook to write into the correct repo by profile, using the same split routing model.
5. Update plan/backlog documentation to reference thread-os and the two-repo setup.
6. Validate with structure checks, flake evaluation, extension smoke tests, and agent sync.

### Risks

- Renaming the extension command removes `/lifeos`; any existing muscle-memory or automation must switch to `/thread-os`.
- The two repos may not have identical workspace skeletons locally, so status/write behavior must fail clearly when a target workspace is missing.
- Renaming user-facing text without migrating existing generated markdown markers could create duplicate generated sections if marker names also change; preserve existing markers unless a deliberate migration is needed.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/thread-os/index.ts --mode json -p --no-tools --no-session '/thread-os status'
PI_OFFLINE=1 THREAD_OS_SCOPE=personal pi --no-extensions -e ./agents/targets/pi/extensions/thread-os/index.ts --mode json -p --no-tools --no-session '/thread-os status'
PI_OFFLINE=1 THREAD_OS_SCOPE=lunar pi --no-extensions -e ./agents/targets/pi/extensions/thread-os/index.ts --mode json -p --no-tools --no-session '/thread-os status'
nix run .#sync-agents
```

## Summary

### What changed

- Renamed the Pi extension directory from `agents/targets/pi/extensions/lifeos/` to `agents/targets/pi/extensions/thread-os/` and changed the command surface from `/lifeos` to `/thread-os`.
- Updated Thread OS repo resolution so personal contexts target `lifeOS` and work/lunar contexts target `lunarOS`, with overrides via `THREAD_OS_PERSONAL_REPO`, `THREAD_OS_WORK_REPO`, and `THREAD_OS_SCOPE`.
- Updated the session-end hook to route personal sessions into `lifeOS` and work sessions into `lunarOS` using the same profile-based split.
- Refreshed the extension README and backlog items to use Thread OS naming.
- Added historical notes to the completed LifeOS docs so the old plans point at the new thread-os split.

### What was tested

- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/thread-os/index.ts --mode json -p --no-tools --no-session '/thread-os status'`
- `PI_OFFLINE=1 THREAD_OS_SCOPE=personal pi --no-extensions -e ./agents/targets/pi/extensions/thread-os/index.ts --mode json -p --no-tools --no-session '/thread-os status'`
- `PI_OFFLINE=1 THREAD_OS_SCOPE=lunar pi --no-extensions -e ./agents/targets/pi/extensions/thread-os/index.ts --mode json -p --no-tools --no-session '/thread-os status'`
- `nix run .#sync-agents`

### Follow-up

- The on-disk `.lifeos` JSONL store layout and generated marker names were intentionally preserved; migrate them only if you decide the repo format itself should also be renamed.
