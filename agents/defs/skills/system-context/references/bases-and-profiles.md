# Bases And Profiles

## Mental Model

- A base is an environment boundary with shared runtime state such as credentials, authentication, and sessions.
- A profile is a configuration overlay inside a base.
- Canonical profile names use `<base>-<profile>` in `NIX_AGENTS_PROFILE`, such as `personal-default` and `work-default`.

## Bases On This Machine

### `personal`

- path prefixes:
  - `~/src/`
  - `~/projects/`
- default profile: `personal-default`
- providers:
  - `personal-zai-key`
  - `personal-minimax-key`
  - local `mlx-dspark/Qwen3-8B-4bit` at `http://127.0.0.1:18080` when the explicit server is running

### `personal-full`

- no automatic path prefixes
- explicit profile: `personal-full`
- providers:
  - `personal-zai-key`
  - `personal-minimax-key`
  - local `mlx-dspark/Qwen3-8B-4bit` at `http://127.0.0.1:18080` when the explicit server is running
- purpose: preserve the complete personal package, agent, and skill surface as an escape hatch

Use it through `pix --profile full` or `NIX_AGENTS_PROFILE=personal-full pi`.

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
An interrupted first download resumes automatically; inspect or remove partial model directories under `~/.cache/huggingface/hub/models--mlx-community--Qwen3-8B-4bit` and `~/.cache/huggingface/hub/models--deepseek-ai--dspark_qwen3_8b_block7` when cleanup is intentional.
The 128K value is a maximum context, not an 8 GiB memory guarantee; memory grows as the KV cache fills.
The first validated 9.5K-token Pi tool-call session used about 6.4 GiB active MLX memory, with a 9.95 GiB one-time loading/calibration peak reported by `/metrics`.

### `work`

- path prefixes:
  - `~/git/github.com/lunarway/`
  - `~/git/github.com/kirksw/lunarOS/`
- default profile: `work-default`
- provider: `work-openai-key`

### `work-full`

- no automatic path prefixes
- explicit profile: `work-full`
- provider: `work-openai-key`
- purpose: preserve the complete work package, agent, and skill surface as an escape hatch

Use it through `pix --profile full --scope work` or `NIX_AGENTS_PROFILE=work-full pi`.

## Profiles In This Repo

### `personal-default`

- base: `personal`
- purpose: lean default with common engineering capabilities
- agents:
  - `the-architect`
  - `code-monkey`
  - `explore`
  - `scout`
  - `bottleneck`
- skills:
  - `add-module`
  - `domain-modeling`
  - `lavish`
  - `nix-agents`
  - `secrets-management`
  - `session-heuristics`
  - `skill-creator`
  - `system-context`
- direct MCP tools: none; integrations are exposed through generated CLI skills when selected
- package surface excludes Context Mode, agent journal, and Bladebro

### `personal-full`

- base: `personal-full`
- agents: all repository-defined agents
- skills: all repository-defined skills
- direct MCP tools: none; integrations are exposed through generated CLI skills
- package surface includes Context Mode, agent journal, and Bladebro

### `work-default`

- base: `work`
- purpose: lean default with dedicated work integrations
- agents:
  - `10xBEAST`
  - `the-architect`
  - `code-monkey`
  - `explore`
  - `scout`
  - `bottleneck`
- skills:
  - `nix-agents`
  - `system-context`
  - `work-mcp`
  - `1password`
  - `granola`
  - `grafana`
  - `hubble-mcp`
  - `linear`
  - `lunar-skills`
  - `slack`
  - `sourcegraph`
  - `swe-pruner`
- direct MCP tools: none; work integrations are exposed through generated CLI skills
- package surface excludes Context Mode and agent journal while retaining `agenticos`
- `agenticos` starts with only `agenticos_enable_tools` active; its domain tools load on demand or when attached work context is restored
- web fetch is denied by default

### `work-full`

- base: `work-full`
- agents: the previous complete nine-agent work set
- skills: the previous complete 23-skill work set
- direct MCP tools: none; work integrations are exposed through generated CLI skills
- package surface includes Context Mode, agent journal, and `agenticos`
- all `agenticos` domain tools are active eagerly
- web fetch is denied by default

## Resolution Rules

Profile selection prefers, in order:

1. `NIX_AGENTS_PROFILE` when explicitly set
2. a `.nix-agents-profile` file in the current directory or one of its parents
3. path-prefix matching against configured bases
4. `personal-default` as the fallback

Unknown explicit profile values fail instead of silently falling back.

## Directory Shape

Generated configuration is organized as:

```text
~/.config/nix-agents/<target>/bases/<base>/profiles/<profile>/
```

Base state is isolated, especially between `personal`, `personal-full`, `work`, and `work-full`.
Repository files under `agents/` remain the source of truth; generated paths must not be edited directly.
