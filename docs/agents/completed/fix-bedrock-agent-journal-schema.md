# fix-bedrock-agent-journal-schema

> Make the agent journal tool schema compatible with Amazon Bedrock Converse.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Amazon Bedrock rejected the active tool list with:

```text
The value at toolConfig.tools.28.toolSpec.inputSchema.json.type must be one of the following: object.
```

The zero-based tool position identifies `agent_journal` in the active profile.
Its parameter schema is a top-level `Type.Union`, which serializes with `anyOf` and no top-level `type`.
Bedrock requires every tool input schema to have `type: "object"`.

## Plan

1. Replace the top-level union with a single object schema.
2. Keep `action` required and expose all action-specific fields as optional schema properties.
3. Continue enforcing action-specific requirements in the existing runtime validation.
4. Add a regression assertion for the top-level schema constructor.
5. Run focused package tests and typechecking, repository checks, and sync the updated local package.

## Risks

- The schema will no longer express conditional required fields to the model.
- Runtime validation remains authoritative and already rejects missing required values.

## Summary

### What changed

- Replaced the `agent_journal` top-level union schema with a Bedrock-compatible object schema.
- Kept `action` required and constrained it to the six supported actions.
- Kept action-specific parameter checks in the existing runtime validation.
- Added a regression test that rejects a top-level union constructor.

### What was tested

- All four focused package tests passed.
- TypeScript typechecking passed.
- Runtime registration produced `agent_journal` with `type: "object"` and required field `action`.
- Repository structure, formatting, whitespace, agent sync, and the full no-eval-cache flake check passed.

### Follow-up

- Restart active Pi sessions so they reload the updated local extension package.
