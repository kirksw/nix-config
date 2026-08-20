# feat-herdr-package-updater

> Add Herdr to `update-packages` and identify packages without update scripts as pinned.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`nix run .#update-packages` only discovers derivations under `packages/`, while Herdr is hard-pinned in `overlays/herdr/default.nix`.
The command therefore leaves Herdr unchanged without mentioning that overlay pin.
Its existing `No updateScript` message also does not express the selected policy that packages without update scripts are intentionally pinned.

## Principles

1. Update Herdr only to the latest stable semantic-version release, excluding drafts and prereleases.
2. Treat every discovered package without `passthru.updateScript` as pinned and state that explicitly in command output.
3. Keep the Herdr package definition in one source file shared by the flake package output and system overlay.
4. Update the Herdr source, Cargo dependencies, Zig dependencies, and coupled Pi integration assets as one rollback-protected operation.
5. Fail without retaining partial Herdr edits when fetching, hashing, or building the release fails.

## Plan

### Scope

- Move the Herdr override into `packages/herdr/default.nix` and have `overlays/herdr/default.nix` call that package.
- Add a Herdr `passthru.updateScript` so the existing package-discovery loop includes it.
- Update `flake/apps.nix` output for packages without an updater.
- Clarify pinned-package behavior in the flake operations reference.
- Update coupled Herdr integration pins when the updater advances Herdr.
- Add a shared Herdr CLI compatibility check for the local Pi extension and terminal-browser.

### Approach

1. Define Herdr once under `packages/herdr/` with its source and dependency hashes.
2. Add an updater that discovers the newest stable GitHub release, runs `nix-update` for the source and custom dependency hashes, refreshes the official Pi integration hash, builds `.#herdr`, and restores all touched files on failure.
3. Replace the overlay implementation with a call to the shared package definition.
4. Report `Pinned: <name> (no updateScript; skipped)` for discovered packages without updater support.
5. Run the Herdr updater, build the updated package, and validate the repository.

### Risks

- A Herdr release can change Cargo or Zig dependency structure in a way `nix-update` cannot infer automatically.
- The official Pi integration path can move between releases.
- Herdr CLI changes can invalidate local Pi extension or terminal-browser compatibility patches even when the package builds.
- Running all package updaters can modify unrelated package pins; focused validation must invoke only the Herdr updater before testing the aggregate app.

## Testing

Commands run to validate:

```sh
nix build .#herdr --no-link
nix build .#terminal-browser --no-link
nix build .#fli --no-link
nix build .#checks.aarch64-darwin.herdr-cli-compatibility --no-link --no-eval-cache
nix build .#checks.aarch64-darwin.pi-herdr-extension-load --no-link --no-eval-cache
./scripts/check-structure.sh
nix flake check --no-build --no-eval-cache
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
git diff --check
```

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._

### What changed

- Moved the Herdr override into the automatically discovered `packages/herdr/default.nix` package and kept the system overlay as a thin caller.
- Added a rollback-protected stable-release updater that semantically sorts release tags, rejects downgrades, refreshes source/Cargo/Zig and Pi integration hashes, builds Herdr, and validates the CLI contract.
- Updated Herdr from 0.8.0 to 0.8.2 and confirmed its CLI is compatible with terminal-browser.
- Added `scripts/check-herdr-cli.sh` and a flake check covering every Herdr command and flag used by the local Pi extension and terminal-browser.
- Changed `update-packages` to report packages without `passthru.updateScript` as pinned instead of announcing them as updates.
- Added a Darwin-only RPATH fix for Fli's `curl-cffi` dependency after the full system build exposed an unrelated nixpkgs packaging failure; Python import checks remain enabled.

### What was tested

- A complete updater run advanced Herdr from 0.8.0 to 0.8.2, refreshed all hashes, built the package, and passed its version check.
- A subsequent updater run reported Herdr already at the latest stable release without modifying files.
- The generated update app includes `-> Updating herdr...` and explicit `-> Pinned <name> (no updateScript; skipped)` entries.
- Herdr, terminal-browser, Fli, both Herdr checks, repository structure, uncached flake evaluation, and the lunar Darwin system toplevel all passed.
- `git diff --check` passed, and independent review found no blocking findings.

### Follow-up

- No follow-up work is required for this feature.
