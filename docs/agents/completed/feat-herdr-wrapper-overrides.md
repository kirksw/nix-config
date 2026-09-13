# feat-herdr-wrapper-overrides

> Upgrade pi-herdr-agents to 1.7.0 and preserve custom Pi wrapper configuration and session overrides.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The upstream launcher forwards the agent directory but not the session override or Nix profile selector.
It computes child session paths under the agent directory even when Pi uses a separate session directory.
The user approved preserving explicit overrides, retaining wrapper execution, and testing launch and resume.

## Plan

### Scope

Package the upstream 1.7.0 release with a repository-owned patch.
Update profile references and adjust the Pi wrapper to preserve explicit overrides.
Add regression coverage without changing unrelated work.

### Approach

1. Inspect upstream launch behavior and wrapper precedence.
2. Package and patch the release and implement wrapper compatibility.
3. Run regression tests, evaluate the flake, sync profiles, and review the diff.

### Risks

Explicit pix profile selection must not inherit another profile's directories.
Child panes do not inherit arbitrary parent-process environment variables.
Generated configuration must only change through repository builds and synchronization.

## Testing

- Passed: Nix package build, including shell-level launch/fork/resume regression tests.
- Passed: upstream 1.7.0 launch suite, 20 tests, with parent profile/session environment removed.
- Passed: built Pi wrapper chain across six profiles, custom config/session overrides, quoted paths, and pix precedence.
- Passed: source launcher tests, structure checks, Nix formatting, and diff whitespace checks.
- Passed: built `pi-herdr-agents-extension-load` and `pi-experimental-profiles` checks.
- Passed: flake evaluation with `--no-build --option eval-cache false`.
- Passed: local profile sync and verification that personal/work defaults reference the patched store package.

The initial package evaluation exposed a missing explicit Pi dependency argument, fixed in `flake/packages.nix`.
Independent review attempts exited without output; no review findings or validated guardrail recommendation were available.
Automated regression tests do not make model calls.
After user activation, live child `herdr-overrides-test` completed with `HERDR_OVERRIDE_SMOKE_OK` and preserved the personal-default profile, config directory, and session override.
The harness reported its session under `/Users/kisw/.local/share/nix-agents/pi/sessions/personal-default/`, and the parent verified that file exists.
The child reported an empty `PI_SESSION_FILE`; session placement was verified from the harness result and filesystem, not that environment variable.

## Summary

The pinned 1.7.0 npm release is built as a local Nix package with a repository-owned patch.
Fresh and resumed launches forward the profile and session override, and child session files use the explicit directory directly.
The outer wrapper preserves explicit directories; a final bridge restores config overrides after library profile setup.
Explicit pix selection clears inherited directory overrides.

### Activation

The user performed the Darwin switch and restarted Pi.
The installed wrapper contains the override handling, and the active profile references the patched package.
Agent synchronization alone does not update installed executables.
No generated configuration was edited manually.
