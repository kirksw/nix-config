# feat-agenticos-mlflow-span-attributes

> Add safe structured agenticOS metadata to existing Pi MLflow tool spans.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The shared Pi MLflow tracer already records tool inputs, outputs, and status, but agenticOS reliability and conformance analysis required parsing unstructured result text.
The tracer needs bounded structured attributes without adding MLflow coupling, credentials, or transport behavior to agenticOS.

## Plan

### Scope

- `agents/packages/pi-mlflow-tracer/index.ts`: attach attributes only to `agenticos_` tool spans through the public MLflow span API.
- `agents/packages/pi-mlflow-tracer/agenticos-attributes.ts`: defensively extract common, SQL, mutation, and context metadata.
- `agents/packages/pi-mlflow-tracer/agenticos-attributes.test.ts`: test safe parsing and SQL error classification.

### Approach

1. Inspect the installed `mlflow-tracing` API and current agenticOS result shapes.
2. Add bounded pure extraction helpers that return primitive attributes and tolerate malformed results.
3. Preserve existing transport, authentication, input/output capture, and non-agenticOS behavior.
4. Add focused tests and run package and Nix validation.

### Risks

- SQL engine messages can contain query-derived identifiers, so the tracer emits only a bounded category and never the raw message as an attribute.
- Optional input defaults and implicit objective attachment are not always present in agenticOS results, so the tracer omits unavailable metadata rather than inventing it.
- Existing tool input and output capture remains unchanged and retains its existing data-access implications.

## Testing

Commands run to validate:

```sh
npm run typecheck --prefix agents/packages/pi-mlflow-tracer
npm test --prefix agents/packages/pi-mlflow-tracer
git diff --check
./scripts/check-structure.sh
nix build .#pi-mlflow-tracer --no-link
nix flake check --no-build
```

`nix flake check --no-build` reached the touched tracer package successfully but failed in the repository baseline while evaluating `apps.aarch64-darwin.sync-agents` and `checks.aarch64-darwin.agentic-factory-profiles` with an invalid generated `nix-config-agents-src.drv` store path.
The same failure reproduced from a detached clean-HEAD worktree containing only this feature's files.

## Summary

### What changed

- Added common agenticOS tool, error, and mutation attributes.
- Added SQL scope, limit, result-shape, truncation, and safe error-class attributes.
- Added structured mutation, validation, assessment, attachment, and context attributes when agenticOS exposes them.
- Used only the public `mlflow-tracing` span attribute API.

### What was tested

- Seven focused parsing and classification tests pass.
- The tracer package typecheck and Nix package build pass.
- The focused unit tests, structure check, and `git diff --check` pass.
- The repository-wide no-build flake check has the unrelated baseline failure documented above.

### Follow-up

- No nix-config follow-up is required.
- A future agenticOS change can expose vendor-neutral result metadata for effective SQL defaults, resolved objectives, validation failures, and SQL error categories.
