# feat-homelab-skill

> Replace the narrow microvm-agent skill with a broader homelab operations skill.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The existing `microvm-agent` skill is too narrow. Homelab work in this repo spans declarative microVMs on `nixos-ry4a`, k3s nodes on `nixos-ry6a`/`nixos-ry6b`, remote deployment via the flake's `deploy` output, and cluster-level verification with kubeconfig-managed tooling. The skill should guide those workflows as one coherent operational surface instead of focusing only on imperative microVM lifecycle scripts.

## Plan

### Scope

- `agents/defs/skills/homelab/`
- `agents/presets/default.nix`
- `agents/presets/profiles.nix`
- `docs/agents/feat-homelab-skill.md`

### Approach

1. Add a new `homelab` skill definition and `SKILL.md` with trigger guidance for host deploys, k3s operations, and declarative microVM changes.
2. Add focused references for topology, deploy/verify workflow, and microVM-specific context reused from the old skill.
3. Swap the default preset import from `microvm-agent` to `homelab`.
4. Expose the new `homelab` skill in the explicit `work-default` profile skill list.
5. Validate with structure checks, flake eval, and agent sync.

### Risks

- Replacing the import path means the old `microvm-agent` skill stops being shipped by default; any direct callers must move to `homelab`.
- Homelab guidance can grow too broad, so the main `SKILL.md` must stay procedural and push detail into references.
- `nixos-ry6b` is currently not deployable from `deploy.nix`, so the skill must describe it as a cluster node/config target rather than implying normal deploy availability.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
```

## Summary

### What changed

- Added a new `homelab` skill under `agents/defs/skills/homelab/` covering host deploys, k3s operations, and declarative microVM workflows.
- Added focused references for homelab topology, deploy/verify steps, and `nixos-ry4a` microVM operations.
- Swapped the default preset import from the old `microvm-agent` skill to the new `homelab` skill.
- Added `homelab` to the explicit `work-default` skill list.

### What was tested

- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `nix run .#sync-agents`

### Follow-up

- None.
