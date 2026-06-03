# feat-codex-approvals-reviewer

> Add `approvals_reviewer = "guardian_subagent"` to Nix-managed Codex base settings.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Codex should use the Guardian subagent as the approvals reviewer from managed profile config. The work base already had this setting in its local base settings file, so that file is now declared in Nix as well to avoid drift during switches.

## Plan

### Scope

- `modules/home/programs/ai-agents.nix`

### Approach

1. Add Codex personal and work base `settings/config.toml` files through Home Manager.
2. Preserve existing work-specific model, MCP, and project settings in the managed work file.
3. Validate evaluation.

### Risks

The generated Codex profile config is refreshed when the wrapped `codex` command runs after applying Home Manager changes.

## Testing

Commands run to validate:

```sh
nix eval --impure --raw --expr 'let flake = builtins.getFlake (toString ./.); in flake.darwinConfigurations.lunar.config.home-manager.users.kisw.xdg.configFile."nix-agents/codex/bases/personal/settings/config.toml".text'
nix eval --impure --raw --expr 'let flake = builtins.getFlake (toString ./.); in flake.darwinConfigurations.lunar.config.home-manager.users.kisw.xdg.configFile."nix-agents/codex/bases/work/settings/config.toml".text'
nix flake check --no-build
```

## Summary

### What changed

- Added managed personal Codex base settings containing `approvals_reviewer = "guardian_subagent"`.
- Added managed work Codex base settings preserving the existing work-specific config.

### What was tested

- Evaluated the Home Manager config file text for personal and work Codex base settings.
- Ran flake checks without builds.

### Follow-up

- None.
