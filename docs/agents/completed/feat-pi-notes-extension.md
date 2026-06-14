# feat-pi-notes-extension

> Add a Pi TUI extension for routing quick notes to personal or work notes repositories.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The existing shell `notes-capture` command can capture personal notes, but Pi does not have an interactive note-taking surface that lets the user choose personal/work routing from inside the TUI.

## Plan

### Scope

- `agents/targets/pi/extensions/notes/`
- Generated Pi extension sync through `sync-agents`

### Approach

1. Add a repo-owned Pi extension exposing `/note`.
2. Build a focused TUI editor with a personal/work route toggle.
3. Save notes into the selected notes repository under `raw/quicknote/YYYY/MM`.
4. Include frontmatter and commit the created note in the target repo.
5. Validate loadability and generated sync.

### Risks

- Pi's TUI key encoding may differ for some control keys.
- Saving depends on the selected notes repo existing and accepting a git commit.

## Testing

Commands run to validate:

```sh
PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/notes/index.ts --mode json -p --no-tools --no-session 'say ok'
PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/notes/index.ts --mode json -p --no-tools --no-session '/note test note'
./scripts/check-structure.sh
nix run .#sync-agents
find ~/.config/nix-agents/pi/bases -path '*/extensions/notes/index.ts' -print
nix flake check --no-build
apps/aarch64-darwin/build lunar
```

## Summary

### What changed

- Added `agents/targets/pi/extensions/notes/`.
- Added `/note [text]` as a Pi TUI command for note capture.
- Added personal/work route inference from the current working directory.
- Added `Tab` route toggling and `Ctrl-S` save behavior.
- Saved notes are created under `raw/quicknote/YYYY/MM` with micronote frontmatter and committed in the selected notes repo.

### What was tested

- Pi can load the extension in offline JSON mode.
- `/note` command path exits cleanly outside TUI mode.
- `sync-agents` installs the extension into personal and work Pi profiles.
- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `apps/aarch64-darwin/build lunar`

### Follow-up

- Try `/note` interactively in Pi and adjust keybindings if Pi emits a different control sequence for `Ctrl-S`.
