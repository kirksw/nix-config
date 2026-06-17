# Hubble MCP agent usage

This repo configures the Hubble dev MCP endpoint as `hubble-mcp-dev` for the work agent profile.

Endpoint:

```text
https://hubble-mcp.dev.lunar.tech/mcp/
```

The MCP endpoint is protected by Okta OAuth through `mcp-auth-proxy`. Use your Lunar Okta account when a client asks you to authenticate.

> Current limitation: Hubble MCP has the server endpoint, but no useful tools until the data-source work lands.

## Apply config

After changing MCP config in this repo:

```bash
cd /Users/kisw/git/github.com/kirksw/nix-config
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
```

Restart the target agent app/session after syncing.

## Codex

Generated config:

```text
~/.config/nix-agents/codex/bases/work/profiles/work-default/config.toml
```

Expected stanza:

```toml
[mcp_servers.hubble-mcp-dev]
url = "https://hubble-mcp.dev.lunar.tech/mcp/"
```

Use:

```bash
codex mcp list
codex mcp get hubble-mcp-dev
codex mcp login hubble-mcp-dev
```

Then ask Codex to use `hubble-mcp-dev` for Hubble data questions.

## Claude Code

Generated config:

```text
~/.config/nix-agents/claude/bases/work/profiles/work-default/.mcp.json
```

Expected server entry:

```json
{
  "mcpServers": {
    "hubble-mcp-dev": {
      "type": "http",
      "url": "https://hubble-mcp.dev.lunar.tech/mcp/"
    }
  }
}
```

Use:

```bash
claude mcp list
claude mcp get hubble-mcp-dev
```

Approve the work-profile MCP config if Claude shows it as pending, then use the server by name in prompts.

## Pi

Generated config:

```text
~/.config/nix-agents/pi/bases/work/profiles/work-default/mcp.json
```

Expected server entry:

```json
{
  "hubble-mcp-dev": {
    "url": "https://hubble-mcp.dev.lunar.tech/mcp/",
    "auth": "oauth",
    "lifecycle": "lazy"
  }
}
```

Use in Pi:

```text
/mcp-auth hubble-mcp-dev
/mcp reconnect hubble-mcp-dev
```

Or through the MCP proxy tool:

```text
mcp({ connect: "hubble-mcp-dev" })
mcp({ server: "hubble-mcp-dev" })
mcp({ search: "hubble" })
```

## OpenCode

Generated config:

```text
~/.config/nix-agents/opencode/bases/work/profiles/work-default/opencode.json
```

Expected server entry:

```json
{
  "mcp": {
    "hubble-mcp-dev": {
      "type": "remote",
      "url": "https://hubble-mcp.dev.lunar.tech/mcp/",
      "enabled": true
    }
  }
}
```

Use:

```bash
opencode mcp list
opencode mcp auth hubble-mcp-dev
opencode mcp debug hubble-mcp-dev
```

Then ask OpenCode to use `hubble-mcp-dev` for Hubble data questions.

## Adding prod later

Do not add prod until the prod endpoint is ready and you intend agents to hit it. Mirror the dev entry with a separate name, for example `hubble-mcp-prod`, and point it at:

```text
https://hubble-mcp.prod.lunar.tech/mcp/
```
