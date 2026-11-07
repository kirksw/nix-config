# feat-semantic-svg-default-style

> Make Rough.js level 2 with clean icons the default diagram style and bundle the approved reference.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The user approved the data mesh variant with level 2 rough boundaries, boxes, hatching, and connectors, while keeping icons clean.
They explicitly requested this default, with cleaner alternatives still available.
This replaces the previously approved clean-by-default behavior.

## Plan

### Scope

Update the semantic SVG skill instructions, helper default and tests, reference assets, version, and profile packaging assertions.
Preserve existing diagrams and unrelated working changes.

### Approach

1. Make the style default explicit in the skill and rough-style reference and align the helper's omitted-level default.
2. Bundle the approved PNG and editable SVG with attribution and usage guidance.
3. Test defaults, SVG structure, asset identity, packaging, and repository checks.

### Risks

The reference is a visual guide, not a mandatory domain layout.
Rough styling must not reduce icon or label legibility.
Cleaner user requests and the style of an existing diagram take precedence.

## Testing

- Temporary-copy `npm ci --ignore-scripts --no-audit --no-fund && npm test`: all five tests pass, including the omitted-level default and explicit cleaner levels.
- Structural validation of `assets/datamesh-reference.svg`: passes.
- Byte comparisons of bundled PNG and SVG against the approved diagram: identical.
- Opened and visually inspected the bundled PNG.
- `./scripts/check-structure.sh`, `nixfmt --check agents/defs/skills/semantic-svg-diagrams/default.nix`, and `git diff --check`: pass.
- `nix flake check --no-build` and the `checks.aarch64-darwin.pi-experimental-profiles` build: pass using a temporary source snapshot and `path:` reference, including the new untracked assets without changing the Git index.
- Profile packaging assertions verify both reference files alongside the Rough.js helper resources.

## Summary

### What changed

The skill and helper now default to level 2 rough structure with clean icons.
Cleaner levels and plain SVG remain available on request, and existing diagram styles are preserved unless restyling is requested.
The approved PNG and editable SVG are bundled as style references with source attribution.
The skill version is 1.2.0.

### What was tested

Unit tests, structural validation, asset identity, visual inspection, formatting, repository checks, and packaged profile resources all pass.

### Follow-up

None required.
Profiles were not synced, and existing diagrams were not modified.
