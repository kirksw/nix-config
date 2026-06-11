# feat-remove-local-pi-todo-and-flows

> Remove local Pi todo extension and bundled workflow prompt flows.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Local Pi extension and prompt flow assets are being trimmed before deciding how
to manage external Pi catalog packages. The local `todo` extension and the
`implement`, `implement-and-review`, and `scout-and-plan` prompt flows should no
longer be synced into Pi profiles.

## Plan

### Scope

- `agents/targets/pi/extensions/todo/index.ts`
- `agents/targets/pi/prompts/implement.md`
- `agents/targets/pi/prompts/implement-and-review.md`
- `agents/targets/pi/prompts/scout-and-plan.md`
- `agents/targets/pi/prompts/README`
- `docs/agents/feat-pi-todo-extension.md`
- `docs/BACKLOG.md`

### Approach

1. Remove the local Pi todo extension source.
2. Remove the local Pi prompt flow sources.
3. Keep a non-command placeholder in the prompt directory so Nix can build an
   otherwise-empty prompt asset tree.
4. Remove stale todo feature/backlog docs.
5. Sync generated agent profiles and verify the generated copies are pruned.

### Risks

- Existing Pi sessions may reference commands or prompt flows that no longer
  exist after sync.
- External replacements need a clear packaging policy before being added.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
find /Users/kisw/.config/nix-agents/pi/bases -path '*/extensions/todo' -o -path '*/prompts/implement.md' -o -path '*/prompts/implement-and-review.md' -o -path '*/prompts/scout-and-plan.md'
```

## Summary

### What changed

- Removed the local Pi `todo` extension.
- Removed the local Pi `implement`, `implement-and-review`, and
  `scout-and-plan` prompt flows.
- Removed stale todo extension docs and backlog follow-up.
- Added a `prompts/README` placeholder because the current Pi config generator
  expects a non-empty prompt asset directory.

### What was tested

- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `nix run .#sync-agents`
- Verified no generated `extensions/todo` directory or removed prompt flow files
  remain under `~/.config/nix-agents/pi/bases`.

### Follow-up

- Decide how external Pi catalog packages should be pinned, installed, and
  synced.
