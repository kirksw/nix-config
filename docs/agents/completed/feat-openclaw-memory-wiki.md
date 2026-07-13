# feat-openclaw-memory-wiki

> Enable OpenClaw's bundled memory-wiki plugin for the ry4a assistant.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The ry4a OpenClaw assistant uses QMD as its existing memory backend. The bundled
memory-wiki plugin should be enabled without adding plugin-specific settings.

## Plan

### Scope

- `hosts/nixos/ry4a/openclaw-assistant.nix`
- This feature summary

### Approach

1. Add the bundled `memory-wiki` plugin entry with `enabled = true`.
2. Leave the existing QMD memory backend and all other plugin settings unchanged.
3. Format the Nix and run focused structural and formatting validation.

### Risks

- Plugin behavior depends on the bundled OpenClaw version and its defaults.

## Testing

Commands run to validate:

```sh
nixfmt --check hosts/nixos/ry4a/openclaw-assistant.nix
./scripts/check-structure.sh
git diff --check
nix flake check --no-build
```

## Summary

### What changed

- Enabled `plugins.entries.memory-wiki` for the ry4a OpenClaw assistant.
- Kept QMD as the configured memory backend with no memory-wiki-specific settings.

### What was tested

- Nix formatting check passed.
- Repository structure check passed.

### Follow-up

- None.
