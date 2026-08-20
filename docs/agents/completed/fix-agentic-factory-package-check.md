# fix-agentic-factory-package-check

> Restore the built factory-profile package-surface assertion after intentional package additions.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The `agentic-factory-profiles` check still expects the earlier five-package home factory surface.
The factory bases now intentionally include the local Anthropic communication policy and `pi-verbosity-control`, so building the check fails even though `nix flake check --no-build` only evaluates it successfully.
The normalizer also lacks a stable name for the local policy store path.

## Plan

### Scope

- Update the expected factory package surfaces and path normalizer in `flake.nix`.
- Build the affected check rather than relying on evaluation-only validation.

### Approach

1. Reproduce the assertion failure by building `checks.aarch64-darwin.agentic-factory-profiles`.
2. Add the local Anthropic policy and verbosity-control entries in authoritative package order.
3. Normalize the local policy source path to a stable expected value.
4. Build the factory check and run repository structure and flake-evaluation checks.

### Risks

- Expected package ordering must remain aligned with `piFactoryPackageRefs`.
- Future intentional package changes will require updating this assertion, which is the purpose of the package-surface guardrail.

## Testing

Commands run to validate:

```sh
nix build .#checks.aarch64-darwin.agentic-factory-profiles --no-link --no-eval-cache
./scripts/check-structure.sh
nix flake check --no-build --no-eval-cache
```

## Summary

### What changed

- Added the local Anthropic communication policy and `pi-verbosity-control` to the expected home and work factory package surfaces.
- Added stable normalization for the local policy source path.
- Kept expected ordering aligned with `piFactoryPackageRefs`.

### What was tested

- Reproduced the previous built-check assertion failure.
- Built `checks.aarch64-darwin.agentic-factory-profiles` successfully after the correction.
- Diff, structure, and uncached flake-evaluation checks passed.

### Follow-up

- No follow-up work is required.
