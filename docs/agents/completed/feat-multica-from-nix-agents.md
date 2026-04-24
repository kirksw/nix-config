# feat-multica-from-nix-agents

> Install `multica` on the `lunar` host from the `nix-agents` flake input.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`multica` is already packaged in the `nix-agents` flake, but this repository does not currently
surface it through the shared AI tooling module or enable it for the `lunar` host. The result is
that `multica` is not installed even though the upstream flake already provides the package.

## Plan

### Scope

- `modules/home/programs/ai-agents.nix`
- `hosts/darwin/work/home.nix`
- `docs/agents/feat-multica-from-nix-agents.md`

### Approach

1. Add a `homeModules.multica.enable` option to the shared AI tooling module.
2. Install `inputs.nix-agents.packages.${system}.multica` when that option is enabled.
3. Enable the option for the `lunar` host profile.
4. Validate with a focused Darwin eval/build dry-run.

### Risks

- `multica` is packaged in `nix-agents`, but it does not currently participate in the wrapped
  profile-aware tool flow used by `opencode`, `codex`, `claude`, and `pi`.
- If a future `nix-agents` update renames or removes the package, this repo will need a matching
  input update.

## Testing

Commands run to validate:

```sh
nix eval --impure --expr 'let flake = builtins.getFlake (toString /Users/kisw/git/github.com/kirksw/nix-config); cfg = flake.darwinConfigurations.lunar.config.home-manager.users.kisw; in builtins.concatStringsSep "\n" (builtins.map (pkg: pkg.pname or pkg.name or "") cfg.home.packages)'
nix build .#darwinConfigurations.lunar.system --no-link --dry-run
```

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._

### What changed

- Added `homeModules.multica.enable` to the shared AI tooling module.
- Installed `inputs.nix-agents.packages.${system}.multica` when the option is enabled.
- Enabled `multica` for the `hosts/darwin/work/home.nix` profile used by `lunar`.

### What was tested

- Evaluated `darwinConfigurations.lunar.config.home-manager.users.kisw.home.packages` and confirmed
  the package list includes `multica`.
- Ran `nix build .#darwinConfigurations.lunar.system --no-link --dry-run` successfully after the
  change.

### Follow-up

- None.
