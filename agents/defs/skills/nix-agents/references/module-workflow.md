# Pi Module Workflow

Pi is the only configured target. There is no external generator input; this repository owns the schema, the profile data, and the packaging.

## Repository Layout

| Path | What goes here |
|------|----------------|
| `agents/pi-profiles.nix` | Bases, provider credential mapping, profiles, skill selection, tier mappings |
| `agents/pi-assets.nix` | Skill loading and the per-profile asset build |
| `agents/defs/skills/` | Skill definitions as `skills.<name> = …` |
| `agents/targets/pi/extensions/` | Pi extensions copied into every profile |
| `agents/targets/pi/prompts/` | Pi prompt templates copied into every profile |
| `agents/base-settings.nix` | Per-base `settings.json`, `models.json`, `mcporter.json`, and `env` |
| `modules/home/programs/ai-agents.nix` | The `pi` wrapper and `pix` launcher |

## Adding A Skill

Create the definition, then select it in a profile.

```nix
# defs/skills/my-skill/default.nix
{
  skills.my-skill = {
    description = "One line trigger description.";
    src = ./.;
    version = "1.0.0";
  };
}
```

Inline skills use `content` instead of `src`:

```nix
{
  skills.my-skill = {
    description = "One line trigger description.";
    content = "# My Skill\n\nMarkdown body loaded when the skill triggers.";
    version = "1.0.0";
  };
}
```

Add the file to `skillFiles` in `agents/pi-assets.nix`, then add the skill name to the
target profile's `skills` list in `agents/pi-profiles.nix`. A profile with `skills = [ ]`
selects every defined skill.

## Adding Or Changing A Profile

Profiles and bases live in `agents/pi-profiles.nix`.

```nix
profiles.<name> = {
  base = "<base>";
  skills = [ "skill-a" "skill-b" ];
  tierMapping = {
    A = [ "litellm/openai/gpt-5.6-sol" "zai/glm-5.2" ];
  };
};
```

A base owns providers and commit identity:

```nix
bases.<name> = {
  providers = [ "personal-zai-key" ];
  git = {
    userName = "…";
    userEmail = "…";
    signingKey = "/path/to/key";
  };
};
```

The `pi` wrapper maps each base provider to its `envVar` and exports the base commit
identity at launch, so a new provider needs no wrapper change.

Profiles are addressed as `bases/<base>/profiles/<profile>`. The launcher maps profile
names to bases; update both `modules/home/programs/ai-agents.nix` and
`scripts/check-pi-experimental-launchers.py` when a profile moves to a new base.

## Validation

```bash
./scripts/check-structure.sh
nixfmt --check <changed files>
nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link
nix run .#sync-agents
PI_OFFLINE=1 pi list
```

## Existing Names

- Skills: `add-module`, `agent-browser`, `codex-imagegen`, `domain-modeling`, `google-hotels`, `home-mcp`, `land`, `lavish`, `nix-agents`, `secrets-management`, `session-heuristics`, `skill-creator`, `system-context`, `xcode`
- Profiles: `personal-default`, `personal-fallback`, `personal-browser`, `work-default`, `work-fallback`, `work-browser`
- Providers: `personal-zai-key`, `personal-minimax-key`, `personal-litellm-api-key`, `personal-litellm-cf-client-id`, `personal-litellm-cf-client-secret`, `work-openai-key`
