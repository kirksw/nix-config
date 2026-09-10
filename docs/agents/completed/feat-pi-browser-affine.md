# feat-pi-browser-affine

> Add CLI-backed AFFiNE access exclusively to Pi's home browser profile.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The user approved CLI-backed MCP access restricted to personal-browser, reusing the ry6a endpoint and existing SOPS token.
Existing unrelated worktree edits must remain intact.

## Plan

### Scope

Pi browser profile, base settings, dedicated AFFiNE skill, shared bounded runner, and wrapper generation app.

### Approach

1. Define the skill only in the Pi profile module and select it only for personal-browser.
2. Configure the existing endpoint with an environment-token placeholder.
3. Decrypt the existing SOPS token at runtime without writing plaintext to generated assets or the Nix store.
4. Generate a dedicated wrapper with the existing MCPorter version and reuse bounded output and mutation confirmation.
5. Validate profile isolation, configuration, wrapper discovery, and repository checks.

### Risks

Runtime decryption requires SOPS credentials, potentially a YubiKey touch.
The endpoint uses HTTP over the existing Tailscale network.
Wrapper generation must not embed the bearer token.

## Testing

- Structure, Nix formatting, shell/JavaScript syntax, and diff checks passed.
- Full flake evaluation passed with `--option eval-cache false` after an invalid cached derivation error.
- Agent sync completed; installed AFFiNE configuration and skill are isolated to personal-browser.
- The runner rejects calls outside personal-browser.
- Corrected the default-package expectation for the existing Plannotator addition.
- Authenticated wrapper generation succeeded and rejected embedding a plaintext token.
- Final sync succeeded; the installed wrapper matches the generated source and exists only in personal-browser.
- Ten mutation guard regression checks passed, including AFFiNE actions missed by the generic verb filter.
- Authenticated `get-capabilities` completed through the installed home-browser runner and returned `affine-mcp` capability version 1.
- Rechecked installed skill files, wrapper equality, runtime token placeholder, profile isolation, mutation rejection, syntax, formatting, structure, and diff whitespace successfully.
- The clean-profile Nix regression build now passes, including both scopes and auth migration.
- Built fast-mode passes Pi actual-loader import verification and its dedicated Nix check.
- The locked fast-mode dependency graph reports zero npm audit vulnerabilities.
- Existing local personal-full state makes the clean-profile script unsuitable for direct execution against the live user directory; the isolated Nix check passes without deleting user state.

## Summary

AFFiNE CLI access and its discovery skill are installed exclusively in Pi's home browser profile.
Authenticated runtime verification passed without changing workspace data.
The Plannotator expectation is corrected and the fast-mode dependency graph is aligned and locked.
Final sync and full flake evaluation passed after realizing the agent-source derivation.
The synced browser fast-mode entry loads successfully through Pi's actual extension loader.
A read-only reviewer confirmed locked packaging prevents the observed dependency drift; the new automated load check enforces compatibility.
No task follow-up remains.

## Approved Completion Repairs

The user approved correcting the Plannotator test expectation and a minimal fast-mode dependency repair.
The installed platform-node-shared rc.113 requires Effect rc.113, but fast-mode 0.1.8 pins Effect beta.100.
Fast-mode 0.1.11 still permits transitive release-candidate drift, so package it with a lockfile and a beta.103 platform-node-shared override matching its Effect and platform-node pins.
Use a Nix-built local package to enforce the lock without modifying generated runtime files.
Validate extension import and clean-profile regression checks before completion.
