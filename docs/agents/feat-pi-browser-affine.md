# feat-pi-browser-affine

> Add CLI-backed AFFiNE access exclusively to Pi's home browser profile.

## Status

- [x] Plan
- [x] Implement
- [ ] Test
- [ ] Complete

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
- The existing profile regression script fails before AFFiNE assertions because its expected default packages omit the pre-existing Plannotator addition.
- Authenticated wrapper generation succeeded and rejected embedding a plaintext token.
- Final sync succeeded; the installed wrapper matches the generated source and exists only in personal-browser.
- Ten mutation guard regression checks passed, including AFFiNE actions missed by the generic verb filter.
- Authenticated `get-capabilities` completed through the installed home-browser runner and returned `affine-mcp` capability version 1.
- Rechecked installed skill files, wrapper equality, runtime token placeholder, profile isolation, mutation rejection, syntax, formatting, structure, and diff whitespace successfully.
- Full profile regression still fails at the pre-existing default-package expectation before AFFiNE assertions.
- Completion is held pending resolution of that unrelated regression.

## Summary

AFFiNE CLI access and its discovery skill are installed exclusively in Pi's home browser profile.
Authenticated runtime verification passed without changing workspace data.
The remaining blocker is the unrelated Plannotator expectation in `scripts/check-pi-experimental-profiles.py`.
