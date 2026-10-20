# Nix Coding Style

Follow these conventions when writing Nix code in this repository.

## Formatting

- Use 2-space indentation
- Format `.nix` files with `nixfmt` (RFC style; installed by `homeModules.neovim`) before committing: `nixfmt <file>`
- Check format without modifying: `nixfmt --check <file>`

## Linting

Run the checks on the files you changed. A repository-wide run reports findings that predate your change.

```bash
statix check <changed .nix files>
nix run nixpkgs#deadnix -- --fail <changed .nix files>
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

- Use kebab-case for agent, skill, and MCP names: `agents.my-agent`, `skills.nix-config`
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
nixfmt <changed .nix files>
statix check <changed .nix files>
nix run nixpkgs#deadnix -- --fail <changed .nix files>
nix flake check --no-build
```

Use `--no-build` on the macOS work host; see the case-insensitive store note in [`flake-ops.md`](flake-ops.md).
