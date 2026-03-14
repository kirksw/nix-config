# Secrets Inventory

This document tracks all SOPS-encrypted secrets in this repository.

## Secrets Structure

```
secrets/
├── api/
│   ├── default.yaml    # ZAI API key
│   └── lunar.yaml      # OpenAI API key (lunar work), Anthropic API key (placeholder)
├── cloudflare/
│   └── ry6a-tunnel-token.yaml  # Tailscale tunnel token for ry6a
├── git/
│   ├── kirksw.yaml    # Git profile: Kirk's personal GitHub
│   ├── lunarway.yaml   # Git profile: Lunarway work
│   └── pat.yaml       # GitHub Personal Access Token
├── k8s/
│   ├── homelab.yaml   # kubeconfig for homelab k3s cluster
│   ├── node.yaml      # k3s node join token
│   └── flux.yaml      # (TODO: add) AGE key for flux to decrypt k8s-config secrets
└── ssh/
    ├── default.yaml   # Default SSH private key
    ├── k8s.yaml      # SSH key for k8s infrastructure
    ├── kirksw.yaml   # SSH key for personal GitHub
    ├── lunarway.yaml # SSH key for work GitHub
    ├── ry4a-root.yaml      # SSH key for ry4a root user
    ├── ry4a.yaml          # SSH key for ry4a personal
    ├── ry6a-root.yaml     # SSH key for ry6a root user
    ├── ry6a.yaml         # SSH key for ry6a personal
    └── ry6b-root.yaml    # SSH key for ry6b root user
```

## Key Management

### AGE Keys

| Key Name | Public Key | Purpose |
|----------|------------|---------|
| main | `age15p8k9vll4k7uqgmqydcn5n09dzc4dlw4nq6zwlnunnurpxg8wqlsyu9mlz` | Default key - personal secrets |
| k8s | `age1e4scgj83r7yddwk96sm8ghdes309e7lze2rq73ufmngkhpaa74vsqndxsx` | k8s infrastructure secrets |
| flux | `age1NEWKEY` (TBD) | Flux CD secrets decryption for cntd-io/k8s-config |

### Encryption Rules (from `.sops.yaml`)

- `secrets/ssh/ry(4a|6a|6b)-root\.yaml$` → requires main + k8s keys
- `secrets/k8s/.*\.yaml$` → requires main + k8s keys
- `secrets/cloudflare/.*\.yaml$` → requires main + k8s keys
- All other secrets → requires main key only

## Adding New Secrets

1. Create the YAML file in the appropriate directory
2. Add the secret content with unencrypted values
3. Encrypt with: `sops secrets/file.yaml`
4. The file will be encrypted with the appropriate keys based on `.sops.yaml` rules
5. Add the secret to `modules/home/programs/sops.nix` if it needs to be available on the host

## Flux Key for k8s-config

The flux key (`flux`) is used to decrypt secrets in the `cntd-io/k8s-config` repository.

### Setup

1. Generate a new flux AGE key (run: `nix run nixpkgs#age -- agekeygen`)
2. Add the public key to the k8s-config repo's `.sops.yaml`
3. Add the private key to `secrets/k8s/flux.yaml` (encrypted with main + k8s keys)
4. After switch, the key is available at `~/.config/sops/age/keys.txt`

### Usage

To decrypt secrets in k8s-config:
```bash
cd /path/to/k8s-config
sops secrets/...
```

The sops CLI will automatically use the flux key from `~/.config/sops/age/keys.txt`.
