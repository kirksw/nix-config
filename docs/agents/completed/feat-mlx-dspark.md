# feat-mlx-dspark

> Add a reproducible mlx-dspark CLI and a local mlx-dspark model provider for personal Pi profiles on Apple Silicon.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

[mlx-dspark](https://github.com/ARahim3/mlx-dspark) runs DSpark and DFlash speculative decoding through Apple's MLX framework.
It can generate directly or serve OpenAI-compatible and Anthropic-compatible APIs; this setup binds it explicitly to `127.0.0.1:18080` because port 8080 is already occupied locally.
The upstream documentation includes a Pi provider configuration and recommends a tool-capable Qwen model for local coding agents.

The selected scope is the engine CLI plus a Pi provider.
The native SwiftUI application is excluded because it is not notarized, installs a mutable app-owned Python runtime, and is not needed for Pi integration.
Model weights are also excluded from Nix because they are large, selected at runtime, and downloaded into the Hugging Face cache on first use.

Research was performed against mlx-dspark engine `0.14.0` and app `0.7.0` on 2026-08-20.
The engine requires Apple Silicon, Python 3.10 or later, `mlx >= 0.32.0`, `mlx-lm >= 0.31.3`, and `mlx-vlm >= 0.6.12`.
The current nixpkgs input provides suitable MLX and mlx-lm versions but only mlx-vlm `0.4.4`, so packaging mlx-vlm `0.6.12` or later is an explicit implementation gate.

Sources:

- [mlx-dspark repository and README](https://github.com/ARahim3/mlx-dspark)
- [mlx-dspark 0.14.0 on PyPI](https://pypi.org/project/mlx-dspark/0.14.0/)
- [mlx-vlm 0.6.12 on PyPI](https://pypi.org/project/mlx-vlm/0.6.12/)
- [mlx-dspark releases](https://github.com/ARahim3/mlx-dspark/releases)

## Principles

- Keep the package and provider reproducible; do not run `pip install` or `uv tool install` during activation.
- Bind the API to loopback and do not expose local inference to the LAN or tailnet by default.
- Keep server startup explicit in the first version to avoid hidden model downloads and persistent unified-memory use.
- Keep model weights outside the Nix store and document their mutable cache and disk usage.
- Configure Qwen3-8B 4-bit with a 128K maximum context, while treating the earlier 8 GiB memory goal as a short-context target rather than a worst-case guarantee.
- Add the provider only to personal Pi profiles unless work-policy approval is obtained separately.
- Do not make the local provider the default model until tool-use quality and prompt-budget behavior are measured.

## Plan

### Scope

Expected files and surfaces:

- `packages/mlx-dspark/default.nix`: pinned engine and Python dependency closure.
- `packages/mlx-dspark/versions.json`: coupled engine and overridden dependency versions and hashes, if the implementation follows existing generated-version patterns.
- `hosts/darwin/work/home.nix`: install the CLI on the Apple Silicon Darwin host.
- `agents/base-settings.nix`: add a personal-profile `models.json` provider definition.
- `flake.nix`: add focused package or server-smoke checks only if package passthrough tests are insufficient.
- `agents/defs/skills/system-context/references/bases-and-profiles.md`: document local-provider availability and startup requirements.
- `docs/agents/feat-mlx-dspark.md`: record implementation and validation, then move it to `docs/agents/completed/`.

A new reusable Home Manager module or launchd service is out of scope for the first version.
Add one later only if repeated manual use shows that explicit startup is too costly.

### Approach

1. **Complete a Python packaging feasibility spike.**
   - Package mlx-dspark `0.14.0` with `python3Packages.buildPythonApplication` and a pinned GitHub or PyPI source.
   - Package or override mlx-vlm at `0.6.12` or later because nixpkgs currently has `0.4.4`.
   - Resolve and pin any missing transitive dependencies, notably the mlx-vlm floors for Transformers, mlx-audio, miniaudio, llguidance, OpenCV, FastAPI, Starlette, and Uvicorn.
   - Reject a runtime `pip`, `uv`, or Homebrew fallback if the dependency closure cannot yet be built reproducibly; document the blocker instead.
   - Restrict `meta.platforms` to `aarch64-darwin`.

2. **Add package-level correctness checks.**
   - Run `pythonImportsCheck = [ "mlx_dspark" ]`.
   - Add `testers.testVersion` for `mlx-dspark --version` if the CLI output is stable.
   - Run upstream tests that do not require model downloads or Metal-heavy inference.
   - Run `mlx-dspark doctor` on Apple Silicon and require successful MLX/Metal initialization.

3. **Add stable update automation.**
   - Add `passthru.updateScript` so `nix run .#update-packages` checks the latest stable, non-prerelease engine release.
   - Update source and dependency hashes atomically and roll back on build or import failure.
   - Keep the mlx-vlm override independently versioned; do not silently raise it when only mlx-dspark changes.
   - Validate the package, doctor command, and no-model API smoke test before accepting an update.

4. **Install the CLI without starting a persistent service.**
   - Add `self.packages.${pkgs.system}.mlx-dspark` to `hosts/darwin/work/home.nix`.
   - Document the initial command as `mlx-dspark serve --model mlx-community/Qwen3-8B-4bit --host 127.0.0.1 --port 18080 --no-thinking --context-window 131072 --kv-bits 8`.
   - Bind explicitly to `127.0.0.1:18080`; port 8080 is already used by Redpanda Console on this machine.
   - Do not download a model during build, activation, or login.

5. **Register a local Pi provider in personal profiles.**
   - Add a shared personal `models.json` in `agents/base-settings.nix` and attach it to `personal` and `personal-full`.
   - Use the upstream-tested Anthropic endpoint first:

     ```json
     {
       "providers": {
         "mlx-dspark": {
           "baseUrl": "http://127.0.0.1:18080",
           "api": "anthropic-messages",
           "apiKey": "mlx-dspark",
           "models": [
             {
               "id": "Qwen3-8B-4bit",
               "contextWindow": 131072,
               "maxTokens": 8192
             }
           ]
         }
       }
     }
     ```

   - Add `mlx-dspark/Qwen3-8B-4bit` to personal enabled models only if Pi requires explicit allowlisting for custom models.
   - Keep the existing cloud provider and model as defaults.
   - Do not add the provider to work profiles because local model use may have separate data-handling and support implications.

6. **Validate API and agent behavior in two tiers.**
   - Deterministic CI smoke test: start `mlx-dspark serve --no-model` on an ephemeral port, wait for `/health`, query `/v1/models`, and terminate cleanly without downloading weights.
   - Manual hardware acceptance: download `mlx-community/Qwen3-8B-4bit`, run a Pi session through `mlx-dspark/Qwen3-8B-4bit`, and verify streaming, tool calls, multi-turn prefix-cache reuse, context-limit handling, and clean shutdown.
   - Measure first-turn prompt tokens, time-to-first-token, and peak memory with the lean `personal-default` profile.
   - Exercise both a normal agent context and a progressively enlarged context; document the point at which memory exceeds 8 GiB rather than claiming the 128K maximum fits inside that budget.
   - Confirm the local model does not become the default and that Pi still starts when the server is offline.

7. **Document operations and lifecycle.**
   - Document start, health, model-cache location, disk cleanup, provider selection, and troubleshooting commands.
   - Document that first use downloads target and drafter weights and that unified-memory requirements depend on the selected quantized model.
   - If an always-on service is later requested, design an opt-in Home Manager launchd module that starts with `--no-model`, uses `KeepAlive = false`, binds loopback, and supports explicit load/unload through the admin API.

### Risks

- **Dependency freshness:** mlx-vlm `0.6.12` is newer than nixpkgs and has a broad dependency closure; this is the largest packaging risk.
- **Binary and Metal assumptions:** MLX is Apple-Silicon-specific, and import success alone does not prove Metal inference works.
- **Large mutable downloads:** target and drafter weights are outside Nix, can consume tens of gigabytes, and need explicit cleanup guidance.
- **Memory pressure:** loading a model consumes unified memory and can affect the rest of the Darwin session. Qwen3-8B 4-bit should approach the 8 GiB target at short context, but a populated 128K KV cache will exceed it even with 8-bit KV quantization; 128K is an allowed maximum, not a guaranteed resident-memory budget.
- **Provider availability:** Pi will list the custom model when the local server is stopped; selection should fail clearly without affecting cloud models.
- **Tool-call quality:** upstream reports good Pi behavior for Qwen3-8B but also reports that some supported models do not converge on Pi's tool protocol.
- **API drift:** Pi's custom-provider schema and mlx-dspark's API emulation can change independently; retain a real tool-call smoke test.
- **Security:** an unauthenticated server is acceptable only while bound to loopback; any broader bind requires authentication and firewall review.
- **Update coupling:** engine, mlx, mlx-lm, mlx-vlm, and Transformers compatibility can regress even when each package builds independently.

## Testing

Planned repository checks:

```sh
nix build .#mlx-dspark --no-link
nix run .#mlx-dspark -- doctor
nix run .#mlx-dspark -- models
./scripts/check-structure.sh
nix run .#sync-agents -- --dry-run
nix run .#sync-agents
nix flake check --no-build --no-eval-cache
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
```

Planned no-download server smoke test:

```sh
port=18080
nix run .#mlx-dspark -- serve --no-model --port "$port" &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
curl --fail --retry 30 --retry-delay 1 "http://127.0.0.1:$port/health"
curl --fail "http://127.0.0.1:$port/v1/models"
kill "$pid"
wait "$pid" || true
```

Planned manual Apple Silicon acceptance:

```sh
mlx-dspark serve \
  --model mlx-community/Qwen3-8B-4bit \
  --host 127.0.0.1 \
  --port 18080 \
  --no-thinking \
  --context-window 131072 \
  --kv-bits 8

pi --provider mlx-dspark --model Qwen3-8B-4bit
```

The manual Pi task must perform at least one read-only tool call and one edit in a disposable repository, then repeat a turn to confirm prefix-cache reuse through `/metrics` or response telemetry.

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._

### What changed

- Added a reproducible Apple Silicon package for mlx-dspark 0.14.0, mlx-vlm 0.6.12, and mlx-audio 0.4.3.
- Replaced nixpkgs' CPU-only MLX build with the official MLX and mlx-metal 0.32.0 wheels and kept their Metal libraries colocated for Nix runtime loading.
- Patched cancellable model downloads to use a wrapped Python environment containing `huggingface-hub`.
- Added stable PyPI update automation with rollback and post-update doctor/API validation.
- Installed mlx-dspark on the Lunar Darwin host and registered `mlx-dspark/Qwen3-8B-4bit` for personal Pi profiles at `127.0.0.1:18080` with a 128K maximum context.
- Added deterministic no-model server and Pi provider-discovery flake checks.

### What was tested

- Package build, Python imports, MLX Metal doctor, model catalog, and no-model HTTP API passed.
- Personal and personal-full synchronization produced valid custom-provider configuration, and Pi listed the 131K-context model while the server was offline.
- A real Qwen3-8B-4bit server loaded the target and DSpark drafter, enabled its probe-verified Metal kernels, and returned an OpenAI-compatible completion.
- A lean personal Pi session sent about 9.5K prompt tokens, called the `read` tool successfully, returned the exact file contents, and reused 9,474 prefix-cache tokens on the next turn.
- A second disposable-repository acceptance run used both `edit` and `read`, verified the resulting file, and an OpenAI-compatible streaming request returned incremental SSE chunks.
- Foreground `Ctrl-C` stopped the server cleanly and released port 18080.
- At the measured agent context, mlx-dspark reported about 6.4 GiB active memory and a 9.95 GiB one-time loading/calibration peak; the 128K limit is therefore not an 8 GiB worst-case guarantee.
- The server reported and accepted the 131,072-token configuration, but intentionally filling the complete context was waived because it would exceed the stated memory target and add a long, hardware-intensive acceptance run. Context-limit behavior remains upstream-tested rather than locally revalidated.
- Repository structure, synchronization, focused flake checks, the uncached no-build flake check, and the Lunar Darwin toplevel build passed during implementation; final reruns are recorded before archival.

### Follow-up

- No required follow-up for the initial explicit-start integration.
