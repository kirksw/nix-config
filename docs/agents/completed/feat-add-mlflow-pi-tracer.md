# feat-add-mlflow-pi-tracer

> Vendor and configure an MLflow tracing extension for every Pi profile.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi sessions need separate personal and work MLflow experiments in the self-hosted, Cloudflare Access-protected MLflow deployment.

## Plan

### Scope

- `agents/packages/pi-mlflow-tracer/`: local copy of the upstream extension and its runtime dependency manifest.
- `agents/base-settings.nix`: add the extension to every Pi profile and set the tracking URL and profile-specific experiment names.
- `modules/home/programs/ai-agents.nix` and `secrets/`: export a SOPS-managed Cloudflare Access service token to Pi at runtime.

### Approach

1. Vendor the upstream extension and update it for the installed Pi API.
2. Add Cloudflare Access service-token headers only for MLflow requests.
3. Configure profile-specific experiment names and runtime-only secret loading.
4. Sync profiles and run targeted extension and Nix validations.

### Risks

- Traces contain prompts, provider payloads, and tool inputs/outputs; the service token must remain SOPS-managed and must be scoped only to MLflow.
- Cloudflare Access service tokens require custom headers, which the upstream MLflow TypeScript client does not expose directly.

## Testing

Commands run to validate:

```sh
npm run typecheck --prefix agents/packages/pi-mlflow-tracer
git diff --check
./scripts/check-structure.sh
nix build .#pi-mlflow-tracer --no-link
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
nix flake check --no-build
nix run .#sync-agents
```

A non-interactive personal-profile smoke test completed and persisted a trace to `pi-home-traces`.

An interactive Pi session opened in `~/git/github.com/kirksw/lunarOS` completed a smoke prompt and persisted a trace to `pi-work-traces`.

## Summary

Vendored and Nix-packaged `@kirksw/pi-mlflow-tracer` for all Pi profiles.

The tracer authenticates to MLflow with SOPS-managed Cloudflare Access service-token headers and records personal and work sessions in separate experiments.

The Pi credential wrapper now loads the selected profile environment so work sessions use `pi-work-traces` rather than inheriting the personal experiment.
