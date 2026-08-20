# feat-work-prompt-budget

> Add a lean work default with a complete `work-full` escape hatch and measurable first-turn prompt budget.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The personal profile now has a lean default, but `work-default` still loads 20 packages, nine agents, and 23 generated skills.
It includes Context Mode and agent journal even for ordinary work sessions.
The current work surface must be preserved before reducing the default.

## Principles

1. Preserve the complete current work surface as `work-full` before changing `work-default`.
2. Keep dedicated work integrations in the default; move general strategy, adversarial review, and infrequent capabilities to the full profile.
3. Remove expensive package families only when the full profile remains an explicit one-command escape hatch.
4. Require a measured clean first turn at or below 9,000 tokens, with 10,000 as the hard limit.
5. Fail closed on unknown profile names and preserve work credential, Git identity, and state isolation.

## Plan

### Scope

- Add lean and full work package bases in `agents/base-settings.nix`.
- Add the `work-full` base/profile and curate `work-default` in `agents/presets/profiles.nix`.
- Update synchronized profile generation in `flake/apps.nix`.
- Update wrapper and `pix` routing in `modules/home/programs/ai-agents.nix`.
- Update model-facing system-context references.

### Approach

1. Preserve the current 20-package work surface as `work-full`.
2. Reduce `work-default` to 18 packages by removing Context Mode and agent journal while retaining `agenticos`, web access, todo, subagents, and Herdr.
   Configure `agenticos` for lazy tool registration so ordinary OS-mode turns expose only `agenticos_enable_tools`; loading the tool or restoring attached work context registers the complete domain-tool set.
3. Preserve the current nine-agent and 23-skill allowlists in `work-full`.
4. Curate `work-default` to six agents: `10xBEAST`, `the-architect`, `code-monkey`, `explore`, `scout`, and `bottleneck`.
5. Curate `work-default` to 12 skills: `nix-agents`, `system-context`, `work-mcp`, `1password`, `granola`, `grafana`, `hubble-mcp`, `linear`, `lunar-skills`, `slack`, `sourcegraph`, and `swe-pruner`.
6. Support `NIX_AGENTS_PROFILE=work-full pi`, `.nix-agents-profile`, and `pix --profile full --scope work`.
7. Synchronize profiles, verify lean/full package and resource separation, run affected checks, and measure a clean `work-default` first turn.

### Risks

- Work integrations contribute more skill metadata than the personal lean profile, leaving less headroom under the token target.
- Specialist agents and general reasoning skills require explicitly selecting `work-full`.
- Work and work-full must not share state or credentials with personal bases.
- Wrapper routing errors could select the wrong identity or base; generated paths and environment variables require explicit validation.
- CLI HTML re-exports can omit prompt and tool metadata, so provider-reported first-turn input remains authoritative.
- Pi providers that serialize inactive registered tools still charge for those schemas; prompt reduction requires deferring domain-tool registration, not only marking the tools inactive.

## Testing

Commands run to validate:

```sh
node --test scripts/analyze-pi-export.test.mjs
./scripts/check-structure.sh
nix build .#checks.aarch64-darwin.agentic-factory-profiles --no-link --no-eval-cache
nix build .#checks.aarch64-darwin.pi-herdr-extension-load --no-link --no-eval-cache
nix flake check --no-build --no-eval-cache
nix run .#sync-agents -- --dry-run
nix run .#sync-agents
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
```

## Summary

### What changed

- Added `work-full` with the preserved 20-package, nine-agent, and 23-skill work surface.
- Reduced `work-default` to 18 packages, six agents, and 12 dedicated work skills.
- Added full-profile routing through `NIX_AGENTS_PROFILE=work-full pi`, `.nix-agents-profile`, and `pix --profile full --scope work`.
- Added backward-compatible eager/lazy agenticOS tool exposure.
- `work-default` initially registers only `agenticos_enable_tools`, while `work-full` registers the complete agenticOS domain-tool set eagerly.
- Updated synchronized profile documentation and the agenticOS runtime, product, architecture, and operator references.

### What was tested

- The synchronized `work-default` exposes only `agenticos_enable_tools` from agenticOS; `work-full` eagerly exposes the ten-tool Goal–Initiative domain set without the loader.
- An initial static work-default capture reported a 15,429-character system prompt, 13 visible skill entries, 18 active tools, and 15,679 tool-schema characters.
- After the concurrent Goal–Initiative migration completed, a clean `openai-codex/gpt-5.6-terra` first turn using the synchronized work resources reported 8,175 input tokens, 825 below the 9,000-token target and 1,825 below the hard limit.
- An earlier lean-profile measurement reported 14,283 effective first-turn tokens on Bedrock Claude Sonnet 5, down 4,534 tokens from the 18,817 eager-tool baseline; cross-provider token counts remain non-comparable.
- agenticOS passed 89 tests, Markdown-link validation, and its Pi extension-load smoke check after the Goal–Initiative migration and fresh-runtime reload coverage.
- Structure checks, uncached flake evaluation, synchronization, synchronized profile inspection, and the lunar Darwin system build passed.

### Follow-up

- No follow-up work is required for this feature.
