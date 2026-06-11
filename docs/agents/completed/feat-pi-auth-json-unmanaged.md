# feat-pi-auth-json-unmanaged

> Keep Pi work auth state mutable instead of Home Manager-managed.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Home Manager was managing `~/.config/nix-agents/pi/bases/work/settings/auth.json`.
When Pi updated that file for work auth, the next activation saw the real file in
the way of the Nix store link, moved it to `.backup`, and replaced it with the
generated template. That effectively nuked work auth on each switch.

## Plan

### Scope

- `modules/home/programs/ai-agents.nix`

### Approach

1. Remove Pi work `settings/auth.json` from `xdg.configFile`.
2. Keep the generated auth template as a seed file.
3. Add a Home Manager activation step that creates the auth file only when it is
   missing, restores the existing `.backup` when present, and leaves normal
   mutable auth state alone.

### Risks

- If Pi changes its auth file schema, the seed template may need an update.
- The activation intentionally removes only an old symlink at the exact auth
  path so the file can become mutable.

## Testing

Commands run to validate:

```sh
nixfmt modules/home/programs/ai-agents.nix
./scripts/check-structure.sh
nix flake check --no-build
nix eval --impure --expr 'let flake = builtins.getFlake (toString ./.); cfg = flake.darwinConfigurations.lunar.config.home-manager.users.kisw.xdg.configFile; in builtins.hasAttr "nix-agents/pi/bases/work/settings/auth.json" cfg'
apps/aarch64-darwin/build lunar
```

## Summary

### What changed

- Removed Pi work `settings/auth.json` from Home Manager-managed
  `xdg.configFile`.
- Added a Home Manager activation step that makes the exact auth path mutable:
  it removes an old Nix-managed symlink, restores `auth.json.backup` when
  present, and otherwise installs the generated API-key seed only once.

### What was tested

- `nixfmt modules/home/programs/ai-agents.nix`
- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- Targeted eval confirmed
  `nix-agents/pi/bases/work/settings/auth.json` is no longer present in
  `xdg.configFile`.
- `apps/aarch64-darwin/build lunar`

### Follow-up

- None.
