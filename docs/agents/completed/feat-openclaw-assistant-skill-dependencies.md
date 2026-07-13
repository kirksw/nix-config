# feat-openclaw-assistant-skill-dependencies

> Declaratively provision requested OpenClaw skill dependencies in every OpenClaw assistant microVM.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The assistants need the `gifgrep`, `github`, `openai-whisper`, and
`sherpa-onnx-tts` skills usable without mutable runtime installation. PDF
workloads use OpenClaw's built-in PDF analysis tool, with `poppler-utils` and
`qpdf` available in each OpenClaw assistant microVM.

## Plan

### Scope

- `hosts/nixos/ry4a/agent-microvms.nix`
- `hosts/nixos/ry4a/openclaw-assistant.nix`
- `packages/gifgrep/default.nix`
- `packages/sherpa-onnx-runtime/default.nix`
- `packages/sherpa-onnx-lessac-model/default.nix`

### Approach

1. Package the unavailable CLI tools and the x86_64 Linux Sherpa runtime/model from pinned sources.
2. Install them only in OpenClaw-enabled assistant microVMs, alongside the required upstream packages.
3. Enable the skills and pass the immutable Sherpa runtime/model paths to OpenClaw.
4. Retain `poppler-utils`, add `qpdf`, and remove the redundant `nano-pdf` skill and custom package; rely on OpenClaw's built-in PDF analysis tool.

### Risks

- The bundled Sherpa runtime targets the x86_64 Linux assistant microVM platform.
- OpenClaw's built-in PDF analysis behavior depends on the enabled OpenClaw version.

## Testing

Commands run successfully:

```sh
nixfmt --check hosts/nixos/ry4a/agent-microvms.nix hosts/nixos/ry4a/openclaw-assistant.nix packages/gifgrep/default.nix packages/sherpa-onnx-runtime/default.nix packages/sherpa-onnx-lessac-model/default.nix
./scripts/check-structure.sh
git diff --check
nix flake check --no-build
```

## Summary

- All OpenClaw assistant microVMs receive `gifgrep`, `gh`, `poppler-utils`, `qpdf`, `whisper`, and the pinned Sherpa runtime/model.
- The `nano-pdf` skill and custom package were removed.
- OpenClaw's built-in PDF analysis tool is used instead of a redundant plugin; other relevant skills remain enabled and Sherpa receives immutable runtime and voice-model paths.
