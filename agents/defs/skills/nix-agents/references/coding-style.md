# Nix Coding Style

Follow these conventions when writing Nix code in this repository.

## Formatting

- Use 2-space indentation
- Use `nixfmt-rfc-style` (not plain `nixfmt`) as documented by the repo
- Format all `.nix` files before committing: `nix run .#fmt`
- Check format without modifying: `nixfmt --check <file>`

## Linting

```bash
nix run .#lint
statix check .
deadnix --fail .
```

## Module Pattern For `defs/`

Skill definitions are plain attrsets, or functions when they need `pkgs` or `inputs`. Do not add `{ config, lib, ... }:` boilerplate.

```nix
# defs/skills/my-skill/default.nix
{
  skills.my-skill = {
    description = "…";
    src = ./.;
    version = "1.0.0";
  };
}
```

## Module Pattern For `modules/`

Module declarations use NixOS-style options.

```nix
# modules/my-module.nix
{ lib, types, ... }:
{
  options.myOption = lib.mkOption {
    type = types.str;
    default = "";
    description = "…";
  };
}
```

## Config Generation Pattern

Generators produce JSON or YAML strings via `builtins.toJSON`.

```nix
builtins.toJSON {
  agents = lib.mapAttrsToList (name: agent: { inherit name; ... }) config.agents;
}
```

## Naming

- Use kebab-case for agent, skill, and MCP names: `agents.my-agent`, `skills.nix-agents`
- Use camelCase for Nix option paths: `options.tierMapping`, `options.mcpServers`

## Common Patterns

Optional attributes:

```nix
{ required = "value"; }
// lib.optionalAttrs condition { optional = "value"; }
```

Filtering attrsets:

```nix
lib.filterAttrs (name: _: builtins.elem name whitelist) attrset
```

Mapping attrsets to lists:

```nix
lib.mapAttrsToList (name: value: { inherit name; ... }) attrset
```

## Testing

Run before committing:

```bash
nix run .#fmt
nix run .#lint
nix flake check --no-build
```

Use `--no-build` on the macOS work host; see the case-insensitive store note in [`flake-ops.md`](flake-ops.md).
