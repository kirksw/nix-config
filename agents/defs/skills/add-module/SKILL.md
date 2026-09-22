---
name: add-module
description: Interactively add a skill or profile to the local Pi agent configuration. Use when the user wants to create a new skill or profile, understand what each definition does, or get step-by-step guidance wiring it into the build.
---

# Add Module

Guide the user through adding a new local Pi definition under `agents/`. Ask one focused question at a time. Do not create files until the required fields are confirmed.

Pi is the only configured target. This repository owns the profile data and the packaging; there is no external generator input.

## Workflow

1. Help the user choose the module type: skill or profile.
2. Collect the required fields for that module type.
3. Show the Nix block or file shape that should be created.
4. Explain how to wire it into the build.
5. Validate with format, structure, and build checks.
6. Sync the generated config with `nix run .#sync-agents`.

## Read These References As Needed

- `references/module-types.md`: chooser for the two remaining module types
- `references/skill.md`
- `references/profile.md`
- `references/wiring-and-validation.md`

## Working Rules

- Ask for one decision at a time rather than dumping the whole schema on the user.
- Explain what each field is for before asking for it.
- Confirm the collected values before creating or showing code.
- Prefer existing repo patterns over inventing new module shapes.
- Do not offer agent, MCP server, hook, or preset definitions; they were removed.
