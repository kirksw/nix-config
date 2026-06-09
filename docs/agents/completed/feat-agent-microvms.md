# feat-agent-microvms

> Define three persistent assistant microVMs for personal, household, and work knowledge bases.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Three long-lived assistant environments are needed on the `nixos-ry4a` microVM host:

- `personal-assistant` for `https://github.com/kirksw/kb-personal`
- `household-assistant` for `https://github.com/kirksw/kb-household`
- `work-assistant` for `https://github.com/kirksw/kb-lunar`

Each VM will be bootstrapped manually with sandboxed OpenClaw plus GitHub and LLM credentials. The repository should record the intended knowledge-base URL but must not clone private repos or commit tokens.

## Plan

### Scope

- `hosts/nixos/ry4a/agent-microvms.nix`
- `hosts/nixos/ry4a/default.nix`
- `secrets/tailscale/agent-microvms.yaml`
- `.sops.yaml`
- `docs/BACKLOG.md`

### Approach

1. Add a dedicated `agent-microvms.nix` module imported by `nixos-ry4a`.
2. Define three persistent declarative `microvm.vms` entries with `autostart = true`.
3. Allocate each VM 2 vCPU, 4096 MB RAM, a 20 GB persistent `/srv/assistant` volume, a 1 GB persistent `/var/lib/tailscale` volume, and an 8 GB persistent `/var/lib/openclaw` volume.
4. Make the `agent` user's home persistent at `/srv/assistant/home`.
5. Use QEMU user networking and Tailscale inside each guest for remote access.
6. Add SOPS-backed Tailscale auth-key placeholders and mount only each decrypted auth-key directory into its corresponding VM.
7. Record intended KB repo URLs in `/etc/assistant/kb-repo` and `/etc/assistant/profile.json` without cloning repos or adding credentials.

### Risks

- Placeholder or expired Tailscale auth keys only affect first authentication. Machine identity should survive restarts because `/var/lib/tailscale` is persistent.
- `microvm.vms` autostart will launch all three VMs on host switch/boot once applied.
- QEMU user networking is suitable for outbound bootstrap and Tailscale, but direct LAN inbound access depends on Tailscale being authenticated.
- OpenClaw itself is still bootstrapped manually; this config provides persistent home/state locations but does not install OpenClaw.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix eval .#nixosConfigurations.nixos-ry4a.config.microvm.autostart --json
nix eval .#nixosConfigurations.nixos-ry4a.config.sops.secrets."tailscale/microvms/personal-assistant/authKey".key --raw
nix build .#nixosConfigurations.nixos-ry4a.config.system.build.toplevel --no-link --dry-run
```

## Summary

### What changed

- Added three persistent assistant microVM definitions on `nixos-ry4a`.
- Added SOPS-encrypted Tailscale bootstrap auth keys for each VM.
- Persisted `/var/lib/tailscale` so Tailscale machine identity survives the 90-day auth-key window.
- Persisted `/var/lib/openclaw` and `/srv/assistant/home` for manually bootstrapped OpenClaw state and credentials.
- Updated `.sops.yaml` so the new Tailscale secret is encrypted to both the main and host recipient groups.
- Recorded intended KB repo URLs for bootstrap tooling without cloning them.

### What was tested

- Structure checks passed.
- Flake check evaluation passed.
- `nixos-ry4a` autostart list evaluates to the three assistant VMs.
- Host toplevel dry-run build evaluates successfully.

### Follow-up

Added to `docs/BACKLOG.md`:

- Bootstrap sandboxed OpenClaw and credentials inside each assistant VM after first boot.
