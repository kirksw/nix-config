# feat-personal-agent-microvm

> Add a persistent interactive Pi and Herdr microVM on `nixos-ry4a`.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The existing assistant microVMs run bounded assistant services but do not provide a persistent interactive personal agent environment.
A dedicated VM is needed for the `personal-default` Pi profile, remote Herdr sessions, a durable workspace, and manually provisioned Pi credentials.

## Plan

### Scope

This change affects the `nixos-ry4a` agent microVM module, Home Manager SSH configuration, and the homelab microVM reference.

### Approach

1. Add an autostarting `personal-agent` QEMU microVM with a dedicated user, SSH, Tailscale, Pi, and Herdr.
2. Persist the agent home, workspace, and Tailscale state in separate volumes.
3. Generate the `personal-default` Pi profile and overlay Herdr's Pi integration into that profile without introducing import-from-derivation evaluation.
4. Add a `personal-agent` SSH host with agent forwarding disabled.
5. Document remote inspection and Herdr access.

### Risks

Pi credentials are intentionally provisioned manually and stored in the persistent home volume.
The VM shares the existing assistant Tailscale authentication secret, so secret provisioning must remain available on the host.
The Herdr integration is pinned to version `0.8.0` and must be updated deliberately with its hash.

## Testing

Commands run successfully:

```sh
nixfmt --check hosts/nixos/ry4a/agent-microvms.nix modules/home/programs/developer.nix
./scripts/check-structure.sh
git diff --check
nix flake check --no-build --option eval-cache false
nix build --no-link --impure --expr '<personal-agent Pi launcher expression>'
```

Targeted evaluation confirmed the `personal-agent` hostname, autostart behavior, Herdr package, `/home/agent`, `/srv/workspace`, and `/var/lib/tailscale` volumes.
Home Manager evaluation confirmed SSH user `agent`, `IdentitiesOnly = true`, and `ForwardAgent = false`.
The Pi launcher and Herdr-enhanced generated profile built successfully.

## Summary

### What changed

- Added the persistent `personal-agent` microVM to `hosts/nixos/ry4a/agent-microvms.nix`.
- Added remote SSH access through `modules/home/programs/developer.nix`.
- Updated `agents/defs/skills/homelab/references/microvms.md` with operation guidance.
- Kept generated agent source evaluation pure by applying the fetched Herdr extension to the generated personal profile output.

### What was tested

- Nix formatting, repository structure, whitespace, full flake evaluation, focused VM and SSH evaluation, and the personal Pi launcher build.

### Follow-up

- None.
