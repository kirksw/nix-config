# Add or change a Pi profile

1. Ask what needs to differ: skills, model tiers, providers, or base-scoped session/authentication state. Confirm scope and values before editing.
2. Read `../references/profile.md` and `../references/bases-and-profiles.md` for the current layout and selection rules.
3. Edit `agents/pi-profiles.nix`; if creating or moving a base, also check launcher routing in `modules/home/programs/ai-agents.nix` and its profile tests. Do not add profile fields from older nix-agents examples without checking the current schema.
4. Follow `validate-and-sync.md` for checks and rollout.
