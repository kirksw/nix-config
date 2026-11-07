# feat-semantic-svg-roughness

> Add opt-in deterministic Rough.js rendering to the semantic SVG diagram skill.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The existing diagram experiment used coordinate jitter and a second outline, which does not reproduce Rough.js outlines and hatching.
The user approved opt-in levels 0, 1, and 2, deterministic seeds, static portable SVG output, and preservation of editable labels and semantic relationships.

## Plan

### Scope

Change the semantic SVG skill source, its helper dependencies and tests, the profile resource-presence checks, and this feature record.
Do not sync profiles, change existing diagrams, or modify unrelated staged changes.

### Approach

1. Provide a pinned Rough.js build-time helper for SVG geometry fragments.
2. Document temporary writable dependency installation and semantic wrapper integration.
3. Test deterministic levels, geometry, invalid input, portability, and structural integration.
4. Render and visually inspect a three-level comparison.

### Risks

Rough.js roughness values do not guarantee pixel-identical Excalidraw output because Excalidraw also controls shape geometry and other renderer options.
Dependency installation needs npm registry access once; the delivered SVG needs no dependencies.
Roughening can move endpoints and hatch strokes, so visual inspection remains required.

## Testing

- `npm ci --ignore-scripts --no-audit --no-fund && npm test` in a temporary copy: four tests pass, covering deterministic levels, stable shape seeds, supported geometry, and rejected invalid inputs.
- CLI smoke test: generated fragment parses as SVG.
- Assembled six-node comparison at levels 0, 1, and 2: structural validator passes; rendered with installed `rsvg-convert` and visually inspected `/tmp/rough-levels.png`.
- `./scripts/check-structure.sh`, `nixfmt --check agents/defs/skills/semantic-svg-diagrams/default.nix`, and `git diff --check`: pass.
- `nix flake check --no-build` and `nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link`: pass.
- Verified packaging again with a temporary source snapshot containing tracked working files and the new untracked helper files, using the `path:` flake reference: profile check passes with explicit assertions for all five new skill resources.

The ordinary Git flake excludes untracked new files until staged.
A direct `path:.` check was interrupted while copying the large working directory; the bounded temporary source snapshot avoids ignored local data and validates the complete change without changing the Git index.

## Summary

### What changed

- Added pinned Rough.js 4.6.6 manifests, a deterministic static SVG geometry helper, and unit tests.
- Added opt-in rough-style guidance and bumped the skill version to 1.1.0.
- Added profile packaging checks for the new helper, dependency manifests, tests, and reference.
- Preserved clean styling as the default and kept editable text and semantic integration under caller control.

### What was tested

Dependency installation, unit tests, CLI output, assembled semantic SVG structure, visual levels comparison, formatting, repository checks, and complete-source profile packaging pass.

### Follow-up

None required for this scope.
Profiles were not synced, and the existing data mesh diagrams were not changed.
The helper is an explicit geometry generator, not an arbitrary-SVG converter.
