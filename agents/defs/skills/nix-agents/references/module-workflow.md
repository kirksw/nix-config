# Nix-Agents Module Workflow

## Repository Layout

| Directory | What goes here |
|-----------|----------------|
| `agents/defs/agents/` | Local agent definitions as `agents.<name> = …` |
| `agents/defs/skills/` | Local skill definitions as `skills.<name> = …` |
| `agents/defs/mcps/` | Local MCP server defs as `mcpServers.<name> = …` |
| `agents/defs/hooks/` | Local hook definitions taking `{ pkgs }:` |
| `agents/presets/` | Local curated import bundles and profiles |
| upstream `nix-agents/modules/` | Reusable option declarations |
| upstream `nix-agents/lib/generators/` | Reusable per-tool config generators |
| upstream `nix-agents/lib/schemas/` | Reusable JSON schemas for generated outputs |

## Skill Type Shape

```nix
# defs/skills/my-skill.nix
{
  skills.my-skill = {
    description = "One line trigger description.";
    content = "# My Skill\n\nMarkdown body loaded when the skill triggers.";
    resources = { };
    src = null;
  };
}
```

Directory-backed shape:

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

## Agent Type Shape

```nix
# defs/agents/my-agent.nix
{
  agents.my-agent = {
    description = "…";
    model = "balanced";
    mode = "subagent";
    temperature = 0.2;
    prompt = "Implement the task.";
    delegatesTo = [ "other-agent" ];
    skills = [ "skill-name" ];
    mcpServers = [ "server-name" ];
    permissions = {
      edit = "allow";
      bash = "deny";
      task = { default = "deny"; rules = { "other-agent" = "allow"; }; };
      webfetch = "allow";
    };
  };
}
```

## MCP Server Type Shape

```nix
# defs/mcps/my-server.nix
{
  mcpServers.my-server = {
    type = "local";
    command = [ "my-bin" "mcp" ];
    package = null;
    url = null;
    environment = { };
  };
}
```

## Adding A New Definition

1. Create `agents/defs/<type>/<name>.nix` or a directory-backed module when that structure is clearer.
2. Import it from the relevant preset in `agents/presets/`.
3. If an agent references the new skill or MCP server, add it to the agent's `skills` or `mcpServers` list.
4. Run `nix flake check --no-build` (full-build checks are unsupported on the macOS work host; see [`flake-ops.md`](flake-ops.md)).

## Validation Checks

`modules/system.nix` validates:

- `delegatesTo` targets exist in `config.agents`
- `skills` entries resolve to defined skills
- `mcpServers` entries resolve to defined MCP servers
- `task.rules` keys are valid agent names
- profile `agents`, `skills`, and `mcpServers` lists resolve to existing definitions

## Preset Pattern

```nix
# presets/my-preset.nix
{ ... }:
{
  imports = [
    ../defs/agents/my-agent.nix
    ../defs/skills/my-skill.nix
    ../defs/mcps/my-server.nix
  ];
}
```

Directory-backed skills can be imported directly:

```nix
imports = [
  ../defs/skills/my-skill
];
```

## Profile Pattern

```nix
# presets/profiles.nix
{ ... }:
{
  profiles.work = {
    pathPrefixes = [ "~/work/" ];
    agents = [ "code-monkey" "explore" ];
    skills = [ "swe-pruner-mcp" ];
    mcpServers = [ "swe-pruner" ];
    tierMapping = { powerful = "anthropic/claude-sonnet-4-6"; };
    permissions = { webfetch = "deny"; edit = null; bash = null; task = null; };
  };
}
```
