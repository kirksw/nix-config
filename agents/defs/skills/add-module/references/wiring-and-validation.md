# Wiring And Validation

## Wiring

A skill is wired in two edits:

1. Add the definition file to `agents/defs/skills/`.
2. Add its path to `skillFiles` in `agents/pi-assets.nix`.

Then select it in a profile by adding its name to that profile's `skills` list in
`agents/pi-profiles.nix`. A profile with `skills = [ ]` selects every defined skill.

A profile needs no import list: `agents/pi-profiles.nix` is read directly by
`agents/pi-assets.nix`.

## Validation

After creating and wiring the module:

```bash
./scripts/check-structure.sh
nixfmt --check <changed files>
nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link
nix run .#sync-agents
PI_OFFLINE=1 pi list
```

If a build fails with a missing skill name, check the name against the skill definitions and
against `skillFiles` in `agents/pi-assets.nix`.

## Existing Names

- Skills: `add-module`, `agent-browser`, `codex-imagegen`, `domain-modeling`, `google-hotels`, `home-mcp`, `land`, `lavish`, `nix-agents`, `secrets-management`, `session-heuristics`, `skill-creator`, `system-context`, `xcode`
- Profiles: `personal-default`, `personal-fallback`, `personal-browser`, `work-default`, `work-fallback`, `work-browser`
- Providers: `personal-zai-key`, `personal-minimax-key`, `personal-litellm-api-key`, `personal-litellm-cf-client-id`, `personal-litellm-cf-client-secret`, `work-openai-key`
