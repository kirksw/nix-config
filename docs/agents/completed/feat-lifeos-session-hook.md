# feat-lifeos-session-hook

> Write Pi session-end summaries into the reset lifeOS workspace repository.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`gh:kirksw/lifeOS` is being reset to a small durable memory repository for active personal and Lunar work. Pi sessions should append concise summaries into the correct lifeOS workspace at session end, using the active Pi profile/base as the routing authority.

## Plan

### Scope

- `agents/defs/hooks/session-write.nix`
- `docs/agents/feat-lifeos-session-hook.md`
- `docs/BACKLOG.md`

### Approach

1. Keep the existing JSON session start/end hook behavior.
2. Extend the session-end hook to write a markdown summary into `~/git/github.com/kirksw/lifeOS`.
3. Route `personal-*` profiles to `workspaces/personal` and `work-*` profiles to `workspaces/lunar`.
4. Refuse unknown profiles rather than guessing.
5. Use repository basename as the initial project slug when a session has a project path; otherwise write to workspace inbox.
6. Append a session note and refresh only the generated section of the relevant workspace `TRACKER.md`.

### Risks

- Pi hook payloads may not include rich transcript summaries, so the first implementation captures summary fields when present and otherwise falls back to metadata-oriented summaries.
- Project associativity starts conservative: existing project directory name must match the current repository basename, otherwise non-interactive hooks route to inbox. Semantic matching can be added later after session summaries accumulate.
- The hardcoded lifeOS checkout path must exist locally for writes to happen.

## Testing

Commands run to validate:

```sh
nix-instantiate --parse agents/defs/hooks/session-write.nix
nix eval --impure --expr 'let pkgs = import <nixpkgs> {}; m = import ./agents/defs/hooks/session-write.nix { inherit pkgs; }; in builtins.length m.hooks'
# Synthetic session-end runs against temporary session/state directories, then restored lifeOS to HEAD:
# - unknown profile refusal
# - unmatched project routes to inbox
# - manual tracker text preservation
# - existing project association
# - duplicate session filename collision avoidance
nix flake check --no-build
nix run .#sync-agents
```

## Summary

### What changed

- Reset `gh:kirksw/lifeOS` separately to a minimal workspace skeleton and documented the operating model there.
- Extended the Pi session-end hook to append markdown session summaries into the hardcoded lifeOS checkout.
- Added profile-based routing: `personal-*` writes to `workspaces/personal`, `work-*` writes to `workspaces/lunar`, and unknown profiles refuse automatic writes.
- Routed unmatched/non-clear projects to workspace inbox instead of creating projects automatically.
- Updated generated tracker sections without touching manual tracker notes, using collision-resistant session filenames.

### What was tested

- Parsed the hook Nix file.
- Evaluated the hook module and confirmed it still exposes two hooks.
- Ran synthetic session-end hook invocations covering unknown profile refusal, inbox routing, manual tracker preservation, existing project association, and duplicate filename collision handling, then restored test artifacts.
- Ran `nix flake check --no-build`.
- Ran `nix run .#sync-agents` to sync generated agent configs.

### Follow-up

- Added backlog item to enhance semantic associativity when Pi exposes richer stable transcript/session-summary payloads.
