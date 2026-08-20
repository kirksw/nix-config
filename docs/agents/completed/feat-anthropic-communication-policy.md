# feat-anthropic-communication-policy

> Inject a concise communication policy into selected Claude model system prompts.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi should append the requested communication policy when the active model is Claude Fable, Sonnet, or Opus.
The policy must not affect Haiku or non-Claude models.
The extension should apply across direct Anthropic access and compatible providers whose model identifiers identify the same Claude families, including Amazon Bedrock.

## Plan

### Scope

- `agents/packages/pi-anthropic-communication-policy/` — local Pi extension package, policy text, and targeted tests.
- `agents/base-settings.nix` — include the local package in interactive and factory Pi package lists.
- `docs/agents/feat-anthropic-communication-policy.md` — record implementation and validation.

### Approach

1. Create a dependency-free local Pi package with a `before_agent_start` handler.
2. Identify Claude Fable, Sonnet, and Opus from normalized model identifiers while excluding Haiku and unrelated models.
3. Append the policy once to the chained system prompt for matching models.
4. Add tests for direct Anthropic, gateway, and Bedrock identifiers, non-target models, and duplicate injection.
5. Add the package to all generated Pi profile settings, validate, and sync.

### Risks

- Provider model identifiers vary, so matching must handle separators without broad substring false positives.
- Other extensions can modify the chained system prompt before or after this extension.
- The policy increases the system prompt and may invalidate provider prompt caches when first introduced.

## Testing

Commands run:

```sh
npm test --prefix agents/packages/pi-anthropic-communication-policy
node --experimental-strip-types -e 'import("./agents/packages/pi-anthropic-communication-policy/index.ts")'
nixfmt --check agents/base-settings.nix
git diff --check
./scripts/check-structure.sh
nix eval --impure --json --expr '<generated Pi package assertions>'
nix run .#sync-agents
nix flake check --no-build --no-eval-cache
```

The first flake check reached the repository's transient invalid agent-source derivation state.
After `sync-agents` built that derivation, the full no-eval-cache flake check passed.

## Summary

### What changed

- Added a dependency-free local Pi extension that appends the requested communication policy for Claude Fable, Sonnet, and Opus model identifiers.
- Excluded Haiku and non-Claude models and prevented duplicate policy injection.
- Added the package to personal, work, home-factory, and work-factory Pi settings.
- Synced the generated Pi settings.

### What was tested

- Five targeted model matching and system-prompt injection tests passed.
- The extension module loaded successfully with Node's TypeScript stripping.
- Nix formatting, diff whitespace, and repository structure checks passed.
- Generated settings assertions found exactly one package reference in every Pi base.
- Agent configuration sync and the full no-eval-cache flake check passed.

### Follow-up

- None.
