# feat-add-litellm-pi-provider

> Add the private LiteLLM gateway as a dynamically discovered Pi provider for personal profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Personal Pi profiles need to use models served by `https://litellm.cntd.io` without storing credentials in generated configuration or the Nix store.
The endpoint requires both a LiteLLM API key and a dedicated Cloudflare Access service token.
The served model catalogue changes independently of this repository, so Pi must discover it dynamically.

## Plan

### Scope

- `agents/packages/pi-litellm-provider/`: dynamically discover models and register an OpenAI-compatible Pi provider.
- `agents/base-settings.nix`: load the extension and expose its models only in personal and home-factory profiles.
- `agents/presets/{profiles,factory}.nix`: map personal runtime credentials to the extension environment.
- `modules/home/programs/ai-agents.nix`: decrypt and export the three SOPS-managed credential values at wrapper startup.
- `secrets/api/litellm.yaml`: encrypted replacement placeholders for the LiteLLM API key and dedicated Cloudflare Access token.

### Approach

1. Add a small Pi extension that authenticates to LiteLLM and Cloudflare Access, fetches `/v1/model/info` with `/v1/models` fallback, and registers the returned models before Pi startup completes.
2. Add runtime-only credential mappings to personal and home-factory bases.
3. Add encrypted placeholder secrets and SOPS-Nix declarations.
4. Enable an explicit allowlist of dynamically discovered LiteLLM models in personal Pi settings.
5. Run targeted extension, secret, structure, formatting, Nix evaluation, profile-sync, and Darwin build checks.

### Risks

- The dedicated Cloudflare Access service token must also be allowed by the Access application for `litellm.cntd.io`; repository configuration alone cannot create that external policy.
- LiteLLM model metadata can be incomplete, so the extension uses conservative defaults for missing context and output limits.
- Placeholder values must disable the provider rather than be sent over the network.

## Testing

Commands run to validate:

```sh
npm test --prefix agents/packages/pi-litellm-provider
./scripts/check-structure.sh
nixfmt --check agents/base-settings.nix agents/presets/profiles.nix agents/presets/factory.nix modules/home/programs/ai-agents.nix flake.nix
sops filestatus secrets/api/litellm.yaml
yq -r 'keys | .[]' secrets/api/litellm.yaml
nix build path:$PWD#checks.aarch64-darwin.agentic-factory-profiles --no-link -L --option eval-cache false
nix flake check path:$PWD --no-build --option eval-cache false
nix build path:$PWD#darwinConfigurations.lunar.config.system.build.toplevel --no-link --option eval-cache false
nix run path:$PWD#sync-agents --option eval-cache false
```

The extension mapped all 23 models returned by the live LiteLLM `/v1/model/info` endpoint.
A direct-cluster Pi smoke test loaded the extension through `--extension` and listed all 23 models under the `litellm` provider.
Generated settings enable the extension only for `personal`, `personal-full`, and `home-factory` and exclude it from all work profiles.
The SOPS file is encrypted and has the expected three keys.
Interactive decryption was not available in the tool session because no configured YubiKey identity was accessible.

## Summary

### What changed

- Added a Pi package that dynamically discovers LiteLLM models with a ten-second request timeout and registers an OpenAI-compatible provider.
- Added LiteLLM Bearer and dedicated Cloudflare Access authentication without placing values in generated settings or the Nix store.
- Added encrypted replacement placeholders in `secrets/api/litellm.yaml`.
- Scoped the provider and credential loading to personal Pi profiles and home factory only.

### What was tested

- Unit tests cover placeholder suppression, metadata mapping, discovery fallback, and both authentication mechanisms.
- The live LiteLLM catalogue and Pi provider registration both returned 23 models.
- Repository structure, formatting, factory profile assertions, flake evaluation, Darwin build, agent sync, and generated profile scope checks passed.

### Activation requirements

- Replace all three values in `secrets/api/litellm.yaml` with `sops secrets/api/litellm.yaml`.
- Allow the dedicated service token in the Cloudflare Access application for `litellm.cntd.io`.
- Run the Darwin switch wrapper so SOPS-Nix installs the new runtime secrets, then restart Pi.
