# feat-pi-npm-vendor

> Vendor Pi npm packages into content-addressed local sets during activation and `sync-agents`, publish runtime settings with local paths, and never let Pi install npm packages at startup.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

Live `sync-agents` rollout and parent validation completed.
The Home Manager activation hook is configured but requires the next Darwin switch to install it.

## Context

Every Pi base settings file declares npm package sources (`npm:pi-web-access@0.13.0`, `npm:@lunarway/pi-lunar-litellm@0.2.1`, ...). Pi installs these at session startup into a per-profile `<profile>/npm` directory by invoking `npmCommand` (the `pi-npm` registry wrapper). This costs startup time, duplicates the same packages across the six profiles, requires network or a warm per-profile install on first launch, and makes the effective package set depend on when a profile last started.

The approved invariant is stronger than "prefer local": Pi must never install npm packages at startup. The tooling is therefore fail-closed — activation and `sync-agents` fail when the vendored set is missing instead of degrading settings to npm sources.

It also adds `npm:pi-context-decisions@2.2.0` to the work default and browser profiles only.

## Plan

### Scope

- `packages/pi-npm-vendor/` (new): vendoring and settings-publishing tool baked from `agents/base-settings.nix`.
- `flake/packages.nix`, `flake.nix`: package registration and checks.
- `agents/base-settings.nix`: add `npm:pi-context-decisions@2.2.0` to the work package refs.
- `flake/apps.nix`: `sync-agents` stops seeding `settings.json`; it vendors and publishes before profile linking, fail-closed.
- `modules/home/programs/ai-agents.nix`: strict activation hook publishes settings on fresh setups and updates.
- `scripts/pi-npm-stub.sh` (new): offline npm stand-in for sandboxed checks and tests.
- `scripts/check-pi-npm-vendor.sh` (new): offline regression test.
- `scripts/check-pi-experimental-profiles.py`: identity normalization for vendored paths, pin verification, and a no-npm-sources invariant.

### Approach

1. `packages/pi-npm-vendor/default.nix` imports `agents/base-settings.nix` and bakes a manifest mapping each Pi base to its Nix-generated `settings.json`. The script takes no base arguments; it derives `$CONFIG_BASE` from `XDG_CONFIG_HOME`/`HOME` exactly like `sync-agents`.
2. Per base, the script extracts npm sources (string or object form) from the store settings, parses name and pinned version with Pi's `parseNpmSpec` semantics, and installs them into a content-addressed set root `$CONFIG_BASE/pi/npm/<base>/set-<hash>/`, where the hash covers the pinned specs:
   - The set root gets a `package.json` (`private: true`) and a self-`.gitignore`, mirroring Pi's managed npm root.
   - One batch invocation per set: `pi-npm install <specs> --prefix <set> --legacy-peer-deps`, matching Pi's managed install, including peer suppression and the GitHub Packages auth wrapper for `@lunarway` packages. A timeout bounds hung installs.
   - Dependency pins in the set `package.json` are normalized to the exact installed versions after verification, and a `vendor-manifest.json` records name → source, version, path.
3. Generational safety: each spec set builds into its own root. A failed build of a new set never mutates the previously published set, and the settings keep pointing at the last usable generation until the new set verifies. Nothing under the npm root is ever deleted.
4. Caching: when every spec is already installed in the set with a satisfying version (exact pins match exactly; unpinned sources accept any installed version, matching Pi's semantics), npm is not invoked at all. This keeps activation offline-safe once packages are vendored; `PI_OFFLINE=1` skips install attempts the same way.
5. Settings publishing is transactional and fail-closed:
   - The published content is the Nix store settings (runtime-only user keys merged in from an existing file, Nix values winning on conflicts) with npm package entries rewritten to `<set>/node_modules/<name>` paths. Object-form entries keep their filters; non-npm sources, `npmCommand`, and every other settings key are preserved as declared. The `packages` selection comes from Nix alone.
   - Publishing happens only after the whole set verifies, atomically (`mktemp` + `mv`), so a base with an incomplete set keeps its previous settings, and a fresh setup fails without settings rather than publishing npm sources.
   - Existing settings that are not valid JSON fail the run untouched.
   - The tool is always strict: `--strict` is accepted for explicitness; incomplete verification, npm failures, or invalid settings exit non-zero and never print completion.
6. `sync-agents` no longer seeds `settings.json` (other base settings such as `models.json`, `mcporter.json`, and `env` are unchanged). It runs the vendor before the profile sync phase, so profiles link the published settings, and a vendoring failure aborts the sync before any profile changes.
7. Home Manager activation runs the same tool with `--strict` after `writeBoundary`. A switch alone vendors packages and populates or updates `settings.json`, including on fresh setups; a failed vendoring fails the switch.
8. `npm:pi-context-decisions@2.2.0` is added to `piWorkPackageRefs` in `agents/base-settings.nix`; the fallback minimal set replaces `packages` wholesale and personal sets are untouched, so it lands only in work default and browser settings.

### Risks

- Offline switches and syncs fail until the machine has vendored each set once (or the npm cache allows the install); this is the intended fail-closed behavior, not a fallback to startup installs.
- Interactive `pi install`/`pi update --extensions` no longer manage the nix-declared packages (they are local paths now); updates flow through nix-config and re-vendoring. Unpinned refs (`npm:@plannotator/pi-extension`) freeze at their vendored resolution, matching Pi's behavior for installed unpinned refs.
- Old spec sets accumulate under `pi/npm/<base>/` (retention by design; nothing is deleted). Unpinned entries re-resolve only when their set rebuilds.
- Per-set roots duplicate shared packages across sets and bases (a few MB each) in exchange for generational safety and isolation from cross-base version divergence.

## Testing

Commands run to validate:

```sh
nixfmt packages/pi-npm-vendor/default.nix flake/packages.nix agents/base-settings.nix flake/apps.nix modules/home/programs/ai-agents.nix flake.nix
nix build .#pi-npm-vendor
bash scripts/check-pi-npm-vendor.sh ./result/bin/pi-npm-vendor scripts/pi-npm-stub.sh
nix build .#checks.aarch64-darwin.pi-npm-vendor
nix build .#checks.aarch64-darwin.pi-experimental-profiles
nix build .#checks.aarch64-darwin.sync-agents-settings-merge
nix build .#checks.aarch64-darwin.pi-mlx-dspark-provider
./scripts/check-structure.sh
nix flake check --no-build
```

`scripts/check-pi-npm-vendor.sh` covers, fully offline through the stub npm:
fresh-setup publishing (Nix selections with local paths, no npm sources, `npmCommand` preserved), warm-set cache hits with idempotent republish, work-only `pi-context-decisions`, updates preserving runtime-only keys while replacing the package selection, failed new-generation builds preserving the previous usable settings, incomplete verification failing without publishing and without claiming completion, invalid settings failing untouched, dry-run changing nothing, no deletion of anything under the npm root, and a healthy machine completing.

Additional end-to-end validation in scratch config roots:
`sync-agents` with the stub npm publishes settings with zero npm sources and links them into every profile (`check-pi-experimental-profiles.py` passes against the vendored settings); with a failing npm, `sync-agents` exits non-zero, publishes no settings, and leaves profiles untouched.

## Summary

### What changed

- `packages/pi-npm-vendor`: new flake package that builds content-addressed npm sets per base and transactionally publishes `settings.json` with local package paths. Fail-closed: previous settings are preserved on failure; fresh setups fail without settings.
- `flake/apps.nix`: `sync-agents` drops `settings.json` from its seeding, runs the vendor before profile linking, and aborts on vendoring failure.
- `modules/home/programs/ai-agents.nix`: strict `home.activation.piNpmVendor` publishes settings on fresh setups and updates; failed vendoring fails the switch.
- `agents/base-settings.nix`: `npm:pi-context-decisions@2.2.0` in work default and browser package sets only.
- `flake/packages.nix`, `flake.nix`: package registration and checks (`PI_NPM_BIN` stub for sandboxed sync checks; new `pi-npm-vendor` check).
- `scripts/pi-npm-stub.sh`, `scripts/check-pi-npm-vendor.sh`: offline stub npm and regression test.
- `scripts/check-pi-experimental-profiles.py`: vendored-path identities, pin verification, and the no-npm-sources invariant.

### What was tested

- Parent independently passed the four targeted check builds, `nix flake check --no-build`, formatting, structure, and diff checks.
- Live `nix run .#sync-agents` succeeded through the real registry wrapper.
- Targeted live assertions verified all six configured bases have zero npm sources and existing vendored package manifests, with `pi-context-decisions@2.2.0` only in work-default and work-browser.
- The broader live profile checker stops on a retained `subagents` key in personal fallback settings; scratch-profile checks pass, and the existing runtime key was preserved rather than removed.
- Independent review confirmed the invariant and the Home Manager dry-run and test cleanup fixes.

- All commands above pass; the full scratch-root e2e (sync, publish, link, check) and the fail-closed sync abort were verified directly.
- `nix flake check --no-build` is green on `aarch64-darwin`. On `x86_64-darwin` the new package/check fail to evaluate because nixpkgs 26.11 dropped the platform; pre-existing packages (for example `pi-npm`) fail there identically on a clean tree.

### Follow-up

- No remaining implementation work.
- The next normal Darwin switch installs the activation hook; no host switch was performed for this agent-only rollout.
- Optional, only if the user asks later: pruning of superseded spec sets under `pi/npm/<base>/` (deliberately not implemented; nothing is deleted without approval).
