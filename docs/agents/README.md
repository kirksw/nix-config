# Nix Skills Index

This directory contains agent documentation for working with this Nix flake repository.

## Available Skills

### [nix-module-workflow.md](./nix-module-workflow.md)
How to add or modify Nix modules in this repository. Covers:
- Where to place changes
- Module patterns and conventions
- Change procedure

### [nix-flake-ops.md](./nix-flake-ops.md)
Build, test, and apply system configuration. Covers:
- Build and switch commands
- Validation commands
- Common issues and solutions

### [nix-coding-style.md](./nix-coding-style.md)
Coding conventions for Nix files. Covers:
- Formatting rules
- Module structure
- Common patterns
- Testing before commit

### [secrets-management.md](./secrets-management.md)
How to work with encrypted secrets. Covers:
- Adding new secrets
- Editing with sops
- File structure and validation

## Usage

These documents are meant to be loaded as skills by agents when working on this repository. They provide context-specific guidance for Nix-related tasks.

When working on:
- Module changes → use `nix-module-workflow`
- Building/switching → use `nix-flake-ops`
- Writing Nix code → use `nix-coding-style`
- Secret management → use `secrets-management`
