# Session Sources

Check these locations first. Some may not exist on every machine or profile.

## Nix-Agents Session Summaries

Primary lifecycle summaries:

```sh
~/.local/share/nix-agents/sessions/*/*/*.json
```

These are produced by the `session-write` hook when enabled. They contain profile,
project, start/end timestamps, branch, commit, duration, skill versions, and events.

## Codex

Likely locations:

```sh
~/.codex/sessions/**/*.jsonl
~/.local/share/nix-agents/codex/**/*.jsonl
~/.config/nix-agents/codex/**/sessions/**/*.jsonl
```

Prefer repo-local or profile-local paths when there are duplicates.

## Claude

Likely locations:

```sh
~/.claude/projects/**/*.jsonl
~/.local/share/nix-agents/claude/**/*.jsonl
~/.config/nix-agents/claude/**/sessions/**/*.jsonl
```

Claude project paths may be encoded in the filename or directory name.

## Pi

Likely locations:

```sh
~/.local/share/nix-agents/pi/sessions/**/*.jsonl
~/.config/nix-agents/pi/bases/*/profiles/*/sessions/**/*.jsonl
~/.pi/agent/sessions/**/*.jsonl
```

Prefer `~/.local/share/nix-agents/pi/sessions` when present because generated
profile config directories may be refreshed by wrappers.

## Search Strategy

Use `find` for filesystem discovery and `rg` for content filtering:

```sh
find ~/.local/share/nix-agents ~/.codex ~/.claude ~/.pi ~/.config/nix-agents \
  -type f \( -name '*.json' -o -name '*.jsonl' -o -name '*.log' \) 2>/dev/null
```

Useful content filters:

```sh
rg -n -i 'error|failed|exception|denied|permission|sandbox|retry|fixed|passed|user corrected|actually|instead|not what' <files>
```

For JSONL, inspect small slices rather than loading entire files.
