# feat-codex-git-read-approvals

> Add managed Codex exec-policy approvals for remote git read operations.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Codex can run sandboxed local commands, but remote git operations such as clone, fetch, and pull need network/SSH access outside the sandbox. These currently require repeated approval prompts even for routine read-oriented git operations.

## Plan

### Scope

- `modules/home/programs/ai-agents.nix`

### Approach

1. Add desired Codex exec-policy rules for personal and work profiles.
2. Preserve existing runtime-learned rules currently present in each profile.
3. Add allow rules for `git clone`, `git fetch`, `git ls-remote`, and `git pull`.
4. Use Home Manager activation to append missing rules so the rule files remain mutable.
5. Validate Home Manager evaluation for the activation script.

### Risks

`git pull` updates the working tree and can trigger repository behavior through git configuration. It is included because the requested workflow specifically needs pull/fetch style remote git access.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix eval --impure --expr 'let flake = builtins.getFlake (toString ./.); in flake.darwinConfigurations.lunar.config.home-manager.users.kisw.home.activation.codexGitReadApprovalRules.data'
nix flake check --no-build
nix run .#sync-agents
nix build --no-link --impure --expr '(builtins.getFlake (toString ./.)).darwinConfigurations.lunar.config.home-manager.users.kisw.home.activationPackage'
nix eval --raw --impure --expr 'let flake = builtins.getFlake (toString ./.); in flake.darwinConfigurations.lunar.config.home-manager.users.kisw.home.activation.codexGitReadApprovalRules.data' | zsh
```

## Summary

### What changed

- Added a Home Manager activation step that appends desired Codex exec-policy rules to personal and work profile `rules/default.rules` files.
- Kept rule files mutable so Codex can continue adding runtime-learned rules.
- Added allow rules for `git clone`, `git fetch`, `git ls-remote`, and `git pull`.

### What was tested

- `./scripts/check-structure.sh` passed.
- Home Manager evaluation for the activation script passed and included both profile targets.
- `nix flake check --no-build` passed.
- `nix run .#sync-agents` completed successfully after the sync app was added.
- Built the Home Manager activation package and applied the focused Codex rule activation snippet.
- Verified the live personal and work Codex `rules/default.rules` files contain the new git rules.

### Follow-up

- None.
