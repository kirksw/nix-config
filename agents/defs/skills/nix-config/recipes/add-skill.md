# Add a Pi skill

1. Ask for the intended behavior and trigger; clarify one decision at a time. Confirm the values before creating files.
2. Follow `../references/skill.md` for the definition and `../references/module-workflow.md` for the current Pi schema. Use `SKILL.md` plus `default.nix` for a skill with supporting files.
3. Add the definition to `skillFiles` in `agents/pi-assets.nix`, then select its name in the appropriate profiles in `agents/pi-profiles.nix`. A profile with `skills = [ ]` selects all definitions.
4. Follow `validate-and-sync.md` for checks and rollout.

If the user is unsure whether they need a skill or a profile, read `../references/module-types.md`. Do not offer agent, preset, or hook definitions as skill/profile module types.
