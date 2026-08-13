# feat-agenticos-pi-package

> Replace the legacy AgenticOS Pi wrapper with a local Pi package.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The current AgenticOS wrapper launches Pi with `-e` and replaces the `pi` shell alias.
AgenticOS is now used as a Pi package from its local checkout instead.

## Plan

### Scope

- Declare AgenticOS's extension in its local package manifest.
- Add the local package only to the work Pi profile.
- Preserve the `lunarOS` instance selection through work-profile environment settings.
- Remove the legacy Pi wrapper and alias.
- Ensure the Pi wrapper selects the generated configuration directory for the resolved profile.

### Approach

1. Add the Pi package manifest to the AgenticOS checkout.
2. Add the checkout as a local package in work Pi settings.
3. Remove the obsolete Home Manager AgenticOS module and host enablement.
4. Select `PI_CODING_AGENT_DIR` from the resolved Pi profile so work Pi does not inherit the personal profile configuration.
5. Sync and verify the generated Pi configuration and extension load.

### Risks

- The local package requires the configured AgenticOS checkout path to exist.
- The extension has full Pi-process permissions and can modify a configured AgenticOS instance through its domain tools.

## Testing

Commands run to validate:

```sh
# In the AgenticOS checkout
npm run check
PI_CODING_AGENT_DIR="$(mktemp -d)/pi" XDG_CONFIG_HOME="$(mktemp -d)/xdg" PI_OFFLINE=1 pi install "$PWD"

# In nix-config
nix run .#sync-agents
./scripts/check-structure.sh
nix flake check --no-build --option eval-cache false
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
```

All commands above passed.
The generated work Pi settings load the local AgenticOS package and set `AGENTICOS_INSTANCE=lunarOS`.
The legacy `pi-agenticos` wrapper is absent after Darwin activation.
The previous work-Pi smoke test exposed that the wrapper inherited the caller's personal `PI_CODING_AGENT_DIR`.
The wrapper now overrides that variable with its resolved profile directory.
The new wrapper build, full flake evaluation, and Darwin build passed.
The activated wrapper resolves `work-default` to the work profile directory.

## Summary

### What changed

- Declared the AgenticOS checkout as a local Pi package.
- Added it only to work Pi settings and preserved the `lunarOS` instance selection.
- Removed the legacy Pi extension wrapper and alias.
- Made the Pi wrapper set `PI_CODING_AGENT_DIR` from its resolved profile.

### What was tested

- Ran AgenticOS conformance tests and a local Pi package-load test.
- Synced agent settings, built the Darwin configuration, and ran the full flake evaluation.
- Verified that the activated wrapper resolves `work-default` to the work profile directory.

### Follow-up

- Restart existing Pi sessions to load the updated package configuration.
