# Nix Failure Triage

Use this reference before changing code in response to a Nix error. First classify the failure, then pick the smallest validation target that reproduces it.

## Triage Flow

1. Classify the failure as one of: sandbox/daemon access, flake attribute lookup, evaluation, build, or activation.
2. If the error is sandbox/daemon access, rerun with normal Nix daemon access before changing code.
3. If the error is evaluation or build, fix one failure class at a time and rerun; Nix often reveals the next blocker only after the first is resolved.
4. Separate expected warnings from actionable failures in the final report.
5. For activation-only behavior, validate the build in-agent and ask the user to run the switch interactively when sudo or GUI services are involved.

## Known Signatures

| Error signature | Likely cause | First action |
| --- | --- | --- |
| `cannot connect to socket at '/nix/var/nix/daemon-socket/socket': Operation not permitted` | Tool sandbox cannot reach the Nix daemon | Rerun with normal/escalated Nix access before debugging config |
| `opening lock file ... ~/.cache/nix/fetcher-locks/... Operation not permitted` | Tool sandbox cannot write Nix fetcher cache/lock files | Rerun with normal/escalated Nix access |
| Darwin build fails in `apr-util`, often through `subversion` or `serf` | A package such as `pkgs.gitFull` pulled in the `git-svn` dependency chain | Check whether `pkgs.git` is sufficient; avoid `gitFull` unless SVN support is required |
| Home Manager: `Error installing file '.config/.../init.lua' outside $HOME` | A repo-backed or out-of-store config directory is being expanded file-by-file | Inspect `xdg.configFile`; remove `recursive = true` when the directory should be linked as a whole |
| `flake ... does not provide attribute ...` for deep paths such as `inputs.*` or nested config attrs | The shorthand flake selector only addresses exported outputs | Inspect `nix flake show`; use `builtins.getFlake` / explicit `nix eval --expr` for internals |
| `undefined variable` after lint cleanup or refactor | A binding that looked unused is consumed by a generator/check path | Search all generators/checks before deleting bindings; rerun full `nix flake check --no-build` |
| `attribute '<name>' already defined` | Duplicate `let` binding or merged attr definition introduced during edit | Inspect the named file/line and remove one definition, then rerun targeted eval |
| `warning: The following flake outputs are unchecked: deploy` | This repo exposes custom `deploy` output for deploy-rs | Expected unless changing deploy behavior |
| `warning: The check omitted these incompatible systems` | `nix flake check` only checked the current system | Expected unless cross-system validation is required; use `--all-systems` when needed |
| `warning: Git tree ... has uncommitted changes` | Working tree is dirty | Informational unless reproducibility or lockfile purity is the task |

## Darwin / Home Manager Validation

Prefer build-oriented validation from the agent:

```bash
nix flake check --no-build
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
```

Use `nix build .#darwinConfigurations.lunar.system --no-link --dry-run` when you only need a quick dependency/evaluation check.

Only run or ask for `sudo darwin-rebuild switch --flake .#lunar` when activation behavior matters. In noninteractive agent sessions, sudo may hang silently; ask the user to run the switch from their terminal when needed.

## Sync-App Discovery

Before running a documented sync app, verify the current outputs:

```bash
nix flake show --all-systems 2>/dev/null | rg 'sync'
```

This repo exposes `sync-agents` for full generated agent config sync. Lunar backend practice skills are exposed to work profiles through the `lunar-skills` MCP server; `sync-work-skills` remains available only as a legacy/manual overlay helper.
