# feat-pix-profiles

> Replace Pi full/factory/experimental choices with default, fallback, and browser, and describe them with `pix list`.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Promote the experimental Herdr setup to default, preserve the lean setup as fallback, and provide a dedicated browser profile.
Changes apply to Pi, not other targets.

## Plan

### Scope

Pi module composition, base settings, launchers, sync, profile checks, and profile reference documentation.

### Approach

1. Define Pi-only default, fallback, and browser profiles for personal and work scopes.
2. Use new default/browser base paths to avoid reusing mutable legacy settings; retain existing lean bases for fallback.
3. Remove factory wiring and expose `pix list` with descriptions.
4. Validate routing, generated profiles, settings isolation, and browser dependencies.

### Principles And Risks

Preserve home/work isolation and unrelated worktree changes.
Fallback must not require experimental packages.
Browser access uses explicit tools and skills.
Keep legacy session and authentication data; do not delete old runtime directories.
The promoted setup requires Herdr and the existing local pi-extensions checkout.

## Testing

- `python3 scripts/check-pi-experimental-launchers.py`: passed both scopes, selection precedence, arguments, list, help, and menu checks.
- `./scripts/check-structure.sh`, targeted `nixfmt --check`, and `git diff --check`: passed.
- Built `checks.aarch64-darwin.pi-experimental-profiles`, `sync-agents-settings-merge`, and `pi-mlx-dspark-provider`: passed.
- Built `darwinConfigurations.lunar.config.system.build.toplevel`: passed.
- `nix flake check --no-build`: passed after initial invalid source-derivation errors.
- Built `pix list`: printed all three descriptions without starting Pi.
- Native agent-browser opened `https://example.com`, extracted its heading and link, and closed successfully using an isolated temporary profile and installed Chrome.

The initial flake evaluation errors were not reproducible after targeted builds with stable source content.
Read-only review did not establish a general recovery rule, so no unverified failure-triage recommendation was added.

## Definition Of Done

- Pi and pix route to default/fallback/browser for both scopes.
- `pix list` describes all three profiles without starting Pi or fzf.
- Full and factory are absent from active Pi configuration.
- Browser profile includes usable browser tooling and web/travel skills.
- Targeted checks and repository validation pass, or blockers are recorded.

## Summary

Pi now exposes default, fallback, and browser for personal and work scopes.
The former experimental package set is default; lean fallback remains independent.
Full and factory are removed from active Pi configuration without deleting legacy runtime data or changing other targets' profile inventories.
Browser includes agent-browser, Google Hotels, and web search/fetch, with scoped browser sessions, profiles, and download directories.
Bladebro travel skills are intentionally excluded because their browser-state isolation is not verified.
Existing hotel skill session names now include the scope prefix.

Generated configuration is synced with `nix run .#sync-agents`.
The built launchers still require the normal interactive Darwin switch to replace installed `pi` and `pix`; no sudo activation was performed.
Run `sudo apps/aarch64-darwin/switch lunar` before using the new installed commands.
No required implementation follow-up remains.
