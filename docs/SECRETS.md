# Secrets Inventory

This document indexes the SOPS-encrypted files in this repository. `.sops.yaml` is
the canonical source for encryption recipients; Nix modules are the canonical
source for how decrypted values are exposed.

## Secrets Structure

```text
secrets/
├── api/{default,litellm,lunar,mlflow}.yaml
├── assistants/{household,kirk,sanja}.yaml
├── cloudflare/ry6a-tunnel-token.yaml
├── git/{kirksw,lunarway,pat}.yaml
├── k8s/{flux,homelab,node}.yaml
├── ssh/{default,k8s,kirksw,lunarway,ry4a-root,ry4a,ry6a-root,ry6b-root,ry6b}.yaml
└── tailscale/agent-microvms.yaml
```

## Recipient Groups

| Alias | Purpose |
| --- | --- |
| `yubikey-main` | Primary hardware recipient |
| `yubikey-backup` | Backup hardware recipient |
| `manual` | Manual recovery recipient |
| `k8s` | Infrastructure recipient |
| `nixos-ry6b` | Host-specific recipient for `nixos-ry6b` |

Recipient public keys are defined once in [`.sops.yaml`](../.sops.yaml).

## Encryption Rules

| Path | Recipients |
| --- | --- |
| `secrets/ssh/ry6b-root.yaml` | all four shared recipient groups plus `nixos-ry6b` |
| `secrets/ssh/ry(4a\|6a)-root.yaml` | all four shared recipient groups |
| `secrets/k8s/*.yaml` | all four recipient groups |
| `secrets/cloudflare/*.yaml` | all four recipient groups |
| `secrets/tailscale/agent-microvms.yaml` | all four recipient groups |
| `secrets/assistants/*.yaml` | all four recipient groups |
| all other `secrets/*.yaml` files | `yubikey-main`, `yubikey-backup`, and `manual` |

Rules are ordered; the first matching `.sops.yaml` creation rule applies.

## Editing and Adding Secrets

1. Confirm the intended path matches the correct rule in `.sops.yaml`.
2. Create or edit the encrypted file with `sops secrets/<category>/<name>.yaml`.
3. Reference it from the appropriate SOPS-Nix module when it must be available on a host.
4. Verify the committed file contains SOPS metadata and no plaintext value.

Never commit plaintext secrets or place secret values in Nix expressions or the Nix store.
