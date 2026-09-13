# feat-remove-pi-extensions

> Remove five unwanted Pi extensions from managed profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The user requested removal of rpiv-ask-user-question, pi-telegram, pi-anthropic-communication-policy, landing-workflow, and pi-simplify.

## Plan

### Scope

- `agents/base-settings.nix`
- `agents/packages/pi-anthropic-communication-policy/`
- `agents/targets/pi/extensions/landing-workflow/`

### Approach

1. Remove package entries and the unused local package binding.
2. Delete the two local extension implementations, including the removed package's tests and manifest.
3. Validate the settings and repository structure, then record results.

### Principles And Risks

The user approved removal from all managed profiles, deletion of the local implementations, preservation of historical documentation and unrelated configuration, and validation without deployment.
Generated profile files remain untouched.
Running sessions retain loaded extensions until configuration rollout and restart.

## Testing

- `./scripts/check-structure.sh`: passed.
- `nixfmt --check agents/base-settings.nix`: passed.
- `git diff --check`: passed.
- Targeted Nix evaluation of all six Pi settings package lists, using stub package paths and external Python JSON parsing: passed; all requested package names are absent.
- Source inspection confirms both local extension directories are removed.
- `nix flake check --no-build`: blocked by invalid store derivation `588ajg6n3k6l7yvv54mndr9za6z8hz9x-nix-config-agents-src.drv` while evaluating `sync-agents-settings-merge`.
- Retrying with `--option eval-cache false` produced the same failure.
- The initial ad hoc settings check hit Nix string-context restrictions in `builtins.fromJSON`; exporting JSON strings and parsing externally passed.
- A read-only reviewer was asked to validate a documentation note for that validation pitfall but exited without output; no documentation recommendation is validated.
- Follow-up direct evaluation with `nix eval --raw .#checks.aarch64-darwin.sync-agents-settings-merge.drvPath --option eval-cache false`: passed.
- Subsequent `nix flake check --no-build --option eval-cache false`: passed.
- No sync or deployment was run, as approved.

## Summary

The requested source changes are implemented.
Full flake validation subsequently passed after direct evaluation of the failing check.
No source fix or deployment was needed.
Historical docs and unrelated source comments remain unchanged.
