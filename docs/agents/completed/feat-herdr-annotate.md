# feat-herdr-annotate

> Add the full Herdr Annotate plugin locally through Nix.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The plugin provides terminal annotations and document or agent-reply review for all local Herdr sessions, independent of the selected Pi profile.

## Plan

### Scope

Pin plannotator/herdr-annotate at 53b6e3211a4103c3de9d361eb3f3bacc7426d23b and its Plannotator TUI 0.6.0 binary.
Install through Home Manager on Darwin only; do not deploy remote hosts.
Preserve existing keys, using prefix+a and prefix+shift+a for capture and copy, prefix+u for management, prefix+v for documents, and prefix+shift+v for replies.
The configured prefix is Ctrl+A.

### Approach

1. Package immutable plugin assets and pinned runtime dependencies.
2. Register the plugin during Home Manager activation and add non-conflicting bindings.
3. Build with upstream tests and validate the manifest and generated configuration.

### Risks

Activation changes the local Herdr plugin registry.
Document review can send feedback to an agent only when explicitly requested by the user.
The upstream package uses separate mutable plugin state, not its immutable source directory.

### Definition Of Done

Package builds and upstream tests pass.
Configuration validates with existing shortcuts preserved.
Activation and interactive validation status are reported accurately.

## Testing

- `nix build .#herdr-annotate --no-link --print-out-paths` passed with all 68 upstream tests.
- Packaged binary reports `plannotator-tui 0.6.0`.
- Generated Herdr configuration passed `herdr config check` in an isolated configuration directory.
- Parsed configuration confirms five annotation bindings and unchanged zoom, notification, and worktree bindings.
- Linked the Nix-store plugin with `herdr plugin link PATH --enabled`; six actions registered.
- Invoked the annotation manager; Herdr reports success with exit code zero and empty stderr.
- Formatting, structure, and diff checks passed.
- Flake evaluation passed after targeted sync-app evaluation and retry following the recurring invalid agent-source derivation failure.
- Read-only review found no material bugs and confirmed positional-first plugin linking avoids the observed CLI parser failure.

## Operational Notes

Use `herdr plugin link PATH --enabled`, not `herdr plugin link --enabled PATH`, with Herdr 0.8.2.
The latter was rejected despite the help synopsis suggesting options may precede the path.
The active configuration contains all five shortcuts, and Herdr config reload applied with no diagnostics.
No annotation was sent to an agent and clipboard contents were not inspected.

## Summary

The full pinned plugin is built, linked, and its manager action succeeds.
Home Manager will retain the plugin registration across future activations.
The user confirmed the manager, document review, and latest-reply review all open correctly using their shortcuts.
Annotation capture, clipboard export, and feedback delivery were not exercised in this validation.

## Shortcut Correction

Direct document review and annotation feedback delivery were verified live.
Alt-based open shortcuts did not invoke the action in the user session.
With user approval, review now uses prefix+v, reply review uses prefix+shift+v, and manager uses prefix+u.
These avoid Alt handling without changing Ghostty settings or existing Herdr shortcuts.
The replacement shortcuts require activation and user verification.
