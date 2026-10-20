# Layout

## Repository Source

- `agents/pi-profiles.nix`: bases, providers, profiles, and tier mappings
- `agents/pi-assets.nix`: skill loading and the per-profile asset build
- `agents/defs/skills/`: skill definitions
- `agents/targets/pi/extensions/`: Pi extensions
- `agents/targets/pi/prompts/`: Pi prompt templates
- `agents/base-settings.nix`: per-base `settings.json`, `models.json`, `mcporter.json`, and `env`
- `modules/home/programs/ai-agents.nix`: the `pi` wrapper, `pix` launcher, and profile routing

Pi is the only configured target. There is no external generator input.

## Generated Profile Tree

Every profile is generated at:

```text
~/.config/nix-agents/pi/bases/<base>/profiles/<profile>/
```

| Path | Contents |
|------|----------|
| `skills/` | Selected skills for the profile |
| `AGENTS.md` | `agents/AGENTS.md` plus the generated model-tier manifest |
| `hook-manifest` | Hook manifest; empty because no hooks are configured |
| `skill-versions.json` | Skill name to version map |
| `extensions/` | Pi extensions |
| `prompts/` | Pi prompt templates |
| `settings.json` | Linked from the base settings directory |
| `models.json` | Linked from the base settings directory |
| `mcporter.json` | Linked from the base settings directory |
| `auth.json` | Linked within the scope so personal and work do not share login state |
| `npm/`, `sessions/`, `tmp/` | Runtime state created by Pi |

Base-scoped settings live at:

```text
~/.config/nix-agents/pi/bases/<base>/settings/
```

Sessions live at:

```text
~/.local/share/nix-agents/pi/sessions/<profile>/<project>/
```

## Sync

`nix run .#sync-agents` copies the generated store paths into the profile tree and links base
settings. The `pi` wrapper bootstraps any missing asset on launch, so a fresh profile
directory works before the first sync.

Removed profiles leave their directories in place. Sync never deletes session, authentication,
or settings data.
