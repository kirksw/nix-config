# Adding SWE-Pruner MCP to Agent Tools

This document explains how to add the SWE-Pruner MCP server to various AI agent tools.

## What is SWE-Pruner MCP?

SWE-Pruner MCP provides context-aware code pruning tools that reduce token usage by 23-54% when reading large files or searching codebases. It offers two tools:
- `read_pruned(file_path, context_focus_question?)` - Read files with optional pruning
- `search_pruned(pattern, context_focus_question?)` - Search codebase with optional pruning

## Automatic Configuration (Nix)

### OpenCode ✅
Automatically configured when `homeModules.swePrunerMcp.enable = true` and `homeModules.opencode.enable = true`.

The MCP server is added to `~/.config/opencode/opencode.json` with `enabled = true`.

### Cursor ✅
Automatically configured when both modules are enabled.

The MCP server is added to `~/.cursor/mcp.json`.

**Note**: If you had an existing `~/.cursor/mcp.json`, it will be backed up and replaced with a symlink to the nix-managed version.

### Codex ✅
Automatically configured when `homeModules.swePrunerMcp.enable = true` and `homeModules.codex.enable = true`.

The MCP server is written to both profile configs:
- `~/.config/codex/profiles/personal/config.toml`
- `~/.config/codex/profiles/work/config.toml`

The wrapper in `modules/home/programs/codex.nix` sets `CODEX_HOME` to the appropriate profile at runtime.

**Manual Setup:**
If you manage Codex config outside Home Manager, add this to the active profile `config.toml`:
   ```toml
   [mcp_servers.swe-pruner]
   command = "/nix/store/fbmcx56y62l3wl0zm1pcr4rdw2s1zkp7-python3.12-swe-pruner-mcp-0.1.0/bin/swe-pruner-mcp"
   env = { MODEL_PATH = "/Users/kisw/.cache/swe-pruner/models/code-pruner", STATS_FILE = "/Users/kisw/.cache/swe-pruner/stats.json" }
   ```

Or use the Codex CLI:
   ```bash
   codex mcp add swe-pruner --env MODEL_PATH=/Users/kisw/.cache/swe-pruner/models/code-pruner --env STATS_FILE=/Users/kisw/.cache/swe-pruner/stats.json -- /path/to/swe-pruner-mcp
   ```

### Pi 🚫
Pi coding agent doesn't currently support MCP servers.

### Claude 🚫
Claude doesn't have a global MCP configuration location. MCP servers are configured per-plugin.

## Verification

After enabling the modules and switching your nix configuration:

### Check OpenCode
```bash
cat ~/.config/opencode/opencode.json | jq '.mcp."swe-pruner"'
```

Should show:
```json
{
  "type": "local",
  "enabled": true,
  "command": ["/nix/store/.../bin/swe-pruner-mcp"],
  "environment": {
    "MODEL_PATH": "/Users/kisw/.cache/swe-pruner/models/code-pruner",
    "STATS_FILE": "/Users/kisw/.cache/swe-pruner/stats.json"
  }
}
```

### Check Cursor
```bash
cat ~/.cursor/mcp.json | jq .
```

Should show:
```json
{
  "mcpServers": {
    "swe-pruner": {
      "command": "/nix/store/.../bin/swe-pruner-mcp",
      "env": {
        "MODEL_PATH": "/Users/kisw/.cache/swe-pruner/models/code-pruner",
        "STATS_FILE": "/Users/kisw/.cache/swe-pruner/stats.json"
      }
    }
  }
}
```

### Check Codex
```bash
codex mcp get swe-pruner
```

Should show:
```text
swe-pruner
  enabled: true
  transport: stdio
  command: /nix/store/.../bin/swe-pruner-mcp
  args: -
  cwd: -
  env: MODEL_PATH=*****, STATS_FILE=*****
```

## Usage

Once configured, you can use the MCP tools in your agent:

```bash
# Read a large file with pruning
read_pruned(
  file_path="/path/to/large/file.py",
  context_focus_question="How is authentication handled?"
)

# Search codebase with pruning
search_pruned(
  pattern="class.*Service",
  context_focus_question="Which services handle HTTP requests?"
)
```

See the skill documentation in `agents/skills/swe-pruner-mcp/SKILL.md` for more details.
