# nix-agents Monorepo Option (Potential Path)

This document outlines a potential migration path to co-locate `nix-agents` with this repository in a monorepo model.

## Why consider this

This option is a good fit when `nix-config` and `nix-agents` are updated and released together most of the time.

Expected benefits:

- Single PR and commit flow for cross-repo changes
- One dependency update cycle
- Unified CI and release cadence
- Less drift between `nix-config` and `nix-agents`

Tradeoff:

- We lose some independent version boundary between the two projects

## Target layout

- Keep this repository root as the primary flake control plane
- Import `nix-agents` into `./nix-agents` with full history preserved
- Rewire `inputs.nix-agents` to local path (`path:./nix-agents`)
- Keep internal ownership boundaries explicit (docs, CI scopes, review expectations)

## Migration plan (low-risk, history-preserving)

1. Create an integration branch and safety tag:

```bash
git checkout -b chore/monorepo-merge-nix-agents
git tag pre-monorepo-merge
```

2. Import `nix-agents` history into a subdirectory:

```bash
git remote add nix-agents-origin git@github.com:kirksw/nix-agents.git
git fetch nix-agents-origin --tags
git subtree add --prefix=nix-agents nix-agents-origin main
```

3. Rewire flake input in `flake.nix`:

```nix
nix-agents.url = "path:./nix-agents";
```

4. Refresh lockfile and validate:

```bash
nix flake lock --update-input nix-agents
./scripts/check-structure.sh
nix flake check --no-build
nix flake check
nix run .#sync-agents
```

5. Update docs and workflow references:

- Replace guidance that assumes separate repos
- Add a short "monorepo workflow" section (single PR flow, validation commands)

6. Cut over release process:

- Treat one commit as one release unit for both `nix-config` and `nix-agents`
- Keep PR scope labels explicit: `nix-config`, `nix-agents`, or `both`

## Ergonomics follow-ups

Recommended after merge:

1. Add root apps:
- `nix run .#check-all`
- `nix run .#fmt-all`
- `nix run .#sync-agents` as canonical sync entrypoint

2. Add path-aware CI triggers:
- `nix-agents/**` changes run agent checks
- host/module paths run config checks
- mixed changes run full suite

3. Decide external compatibility strategy:
- Archive old `kirksw/nix-agents` repo as read-only with redirect, or
- Keep a mirror flow only if external consumers depend on that repo path

## Decision gate before execution

Decide how lockfiles should work:

- **Option A (recommended here):** root-first workflow; root `flake.lock` is canonical
- **Option B:** retain independent `nix-agents/flake.lock` for occasional standalone subdir development

Given a "release together" model, Option A is usually simpler and easier to operate.
