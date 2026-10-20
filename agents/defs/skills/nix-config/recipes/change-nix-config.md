# Change Nix configuration

1. Locate the authoritative file with `../references/source-of-truth.md` and `../references/layout.md`. Distinguish a persistent Nix change from a generated runtime file.
2. Read `../references/coding-style.md` before editing `.nix` files; use `../references/module-workflow.md` for Pi skill/profile wiring.
3. Make the smallest source change that covers the intended profiles or hosts. Do not hand-edit generated agent files or `CHANGELOG.md`.
4. Follow `validate-and-sync.md` for targeted validation and rollout. If a check fails, use `../references/failure-triage.md` before changing code.
