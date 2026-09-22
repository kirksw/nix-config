# Bases And Profiles

## Mental Model

- A base is an environment boundary with shared runtime state such as credentials, authentication, sessions, and settings.
- A profile is a configuration overlay inside a base that selects skills and model tiers.
- Canonical profile names use `<scope>-<profile>` in `NIX_AGENTS_PROFILE`, such as `personal-default` and `work-default`.
- Pi is the only configured target. There is no external generator input.

## Bases On This Machine

### `personal`

- own path prefixes: none
- hosts the `personal-fallback` profile
- providers:
  - `personal-zai-key`
  - `personal-minimax-key`
  - `personal-litellm-api-key`
  - `personal-litellm-cf-client-id`
  - `personal-litellm-cf-client-secret`
  - local `mlx-dspark/Qwen3-8B-4bit` at `http://127.0.0.1:18080` when the explicit server is running

### `personal-default`

- same providers and commit identity as `personal`
- hosts the `personal-default` profile

### `personal-browser`

- same providers and commit identity as `personal`
- hosts the `personal-browser` profile

### `work`

- own path prefixes: none
- hosts the `work-fallback` profile
- provider: `work-openai-key`
- commits use the Lunar work identity and signing key

### `work-default`

- same providers and commit identity as `work`
- hosts the `work-default` profile

### `work-browser`

- same providers and commit identity as `work`
- hosts the `work-browser` profile

Start the local personal model explicitly before selecting it:

```sh
mlx-dspark serve \
  --model mlx-community/Qwen3-8B-4bit \
  --host 127.0.0.1 \
  --port 18080 \
  --no-thinking \
  --context-window 131072 \
  --kv-bits 8

pi --provider mlx-dspark --model Qwen3-8B-4bit
```

The model and drafter download into `~/.cache/huggingface/hub/` on first use.
Check readiness and runtime memory with `curl http://127.0.0.1:18080/health` and `curl http://127.0.0.1:18080/metrics`.
Use `Ctrl-C` in the foreground server terminal to stop it and release model memory.

## Pi Profiles

Pi has three choices in each scope, listed by `pix list`:

| Choice | Purpose | Personal profile/base | Work profile/base |
|---|---|---|---|
| `default` | Everyday engineering with Herdr orchestration | `personal-default` / `personal-default` | `work-default` / `work-default` |
| `fallback` | Minimal setup: web access, verbosity control, and LiteLLM models only | `personal-fallback` / `personal` | `work-fallback` / `work` |
| `browser` | Browser automation and web/travel research | `personal-browser` / `personal-browser` | `work-browser` / `work-browser` |

```sh
pix list
pix --profile default --scope home
pix --profile fallback --scope work
pix --profile browser --scope home
```

`pix` without `--profile` opens a menu with `default` first.
`pi` without an explicit profile selects `personal-default` or `work-default` from the project scope.
Use `NIX_AGENTS_PROFILE=<profile> pi` or an ancestor `.nix-agents-profile` file for explicit selection.
Herdr child sessions inherit the parent profile through `PI_CODING_AGENT_DIR` when no explicit environment selector is set.
`pix --scope` wins over inferred scope; otherwise scope follows `NIX_AGENTS_PROFILE`, an ancestor profile file, then work path matching, falling back to home.

The `default` and `browser` profiles use `pi-herdr-agents` instead of `tintinweb/pi-subagents` and require Herdr for delegation.
They omit `rpiv-btw`, `context-mode`, and `pi-observational-memory` and load `/Users/kisw/git/github.com/kirksw/pi-extensions/main` (currently `pi-context-flow`).
That checkout and its runtime dependencies must exist on the machine.
`fallback` is minimal: `pi-web-access`, `pi-verbosity-control`, and `pi-litellm-provider` only.
It has no subagents, MCP tooling, tracing, to-do tracking, or permission enforcement, and it does not depend on that checkout or `pi-herdr-agents`.

Browser profiles include `agent-browser`, `google-hotels`, and `system-context` skills.
The personal browser profile also includes `affine` and `home-mcp`.
Browser profiles include the web-access package and have no configured MCP servers.
The launcher uses installed Google Chrome on macOS when available; otherwise run `agent-browser install` or set `AGENT_BROWSER_EXECUTABLE_PATH`.
The launcher gives agent-browser separate persistent browser profiles and session names for personal and work use.
Browser skills do not authorize bookings, payments, or other external commitments without user approval.

## Profiles In This Repo

Every profile selects skills only. The repository defines no custom agents.

### `personal-default`

- base: `personal-default`
- purpose: everyday personal engineering with Herdr orchestration
- skills: `add-module`, `agent-browser`, `codex-imagegen`, `domain-modeling`, `google-hotels`, `home-mcp`, `land`, `lavish`, `nix-agents`, `secrets-management`, `session-heuristics`, `skill-creator`, `system-context`, `xcode`
- package surface: the lean set with the `pi-herdr-agents` replacement

### `personal-fallback`

- base: `personal`
- purpose: minimal personal setup
- skills: the same fourteen skills as `personal-default`
- package surface: `pi-web-access`, `pi-verbosity-control`, `pi-litellm-provider`

### `personal-browser`

- base: `personal-browser`
- purpose: browser automation and web/travel research
- skills: `affine`, `agent-browser`, `google-hotels`, `home-mcp`, `system-context`
- MCP: the AFFiNE HTTP server, used by the generated AFFiNE CLI skill

### `work-default`

- base: `work-default`
- purpose: everyday work engineering with Herdr orchestration
- skills: `1password`, `grafana`, `granola`, `hubble-mcp`, `land`, `lavish`, `linear`, `lunar-skills`, `nix-agents`, `slack`, `sourcegraph`, `system-context`, `work-mcp`
- package surface: the lean set with the `pi-herdr-agents` replacement and `agenticos`

### `work-fallback`

- base: `work`
- purpose: minimal work setup
- skills: the same thirteen skills as `work-default`
- package surface: `pi-web-access`, `pi-verbosity-control`, `pi-litellm-provider`

### `work-browser`

- base: `work-browser`
- purpose: browser automation and web/travel research
- skills: `agent-browser`, `google-hotels`, `system-context`

Full and factory profiles no longer exist for any target.
Old runtime directories and sessions are not deleted by sync; removed profile names fail selection.
Authentication is shared only within the matching personal/work scope, while settings and sessions stay separate.

## Resolution Rules

Profile selection prefers, in order:

1. `NIX_AGENTS_PROFILE` when explicitly set
2. a `.nix-agents-profile` file in the current directory or one of its parents
3. an inherited `PI_CODING_AGENT_DIR` from a parent Herdr session
4. `work-default` for a Lunar project path, otherwise `personal-default`

Unknown explicit profile values fail instead of silently falling back.

## Directory Shape

Generated configuration is organized as:

```text
~/.config/nix-agents/pi/bases/<base>/profiles/<profile>/
```

Settings live under `~/.config/nix-agents/pi/bases/<base>/settings/`.
Sessions live under `~/.local/share/nix-agents/pi/sessions/<profile>/`, honoring the corresponding XDG roots.
Each Pi profile receives the Herdr lifecycle hook at `extensions/herdr-agent-state.ts`.
Repository files under `agents/` remain the source of truth; do not edit generated paths directly.
