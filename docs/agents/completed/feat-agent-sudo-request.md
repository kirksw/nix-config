# feat-agent-sudo-request

> Add a human-confirmed sudo workflow request/approval broker for agent-triggered operations.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Agents cannot use interactive sudo prompts from the harness, and widening sudo timestamp behavior is not desirable. We want an auditable handoff where an agent can request a privileged workflow, then the human approves from their own terminal/session with normal sudo/Touch ID prompts.

## Plan

### Scope

- Add `scripts/agent-sudo-request.py` to create request records under `${XDG_STATE_HOME:-~/.local/state}/nix-config/sudo-requests`.
- Add `scripts/agent-sudo-approve.py` to inspect, confirm, authenticate sudo, and run a requested command from the recorded cwd.
- Expose both via flake apps: `agent-sudo-request` and `agent-sudo-approve`.
- Document usage in the completed feature doc.

### Approach

1. Requests store exact argv, cwd, metadata, and optional reason as mode `0600` JSON.
2. Approval reads a request by id/path, prints the command and repo state, requires an interactive confirmation, runs `sudo -v`, then executes the command normally from the recorded cwd.
3. Approval uses a lock directory and a `.done.json` record to prevent concurrent/replayed approvals.
4. Optional request flag opens Terminal.app with the approval command for convenient handoff.

### Risks

- The command still executes with the user's authority after confirmation; the preview must be clear.
- Request files are local user state, not a security boundary against the same user. Approval is the trust boundary.
- Opening Terminal.app is macOS-specific and optional.

## Usage

Agent side:

```sh
nix run .#agent-sudo-request -- \
  --reason "Install syncMode-aware Darwin wrappers" \
  --open-terminal \
  -- apps/aarch64-darwin/switch lunar
```

Human side, if Terminal was not opened automatically:

```sh
nix run .#agent-sudo-approve -- <request-id>
```

The approver prints the request details, requires typing the request id, runs `sudo -v`, then executes the recorded command from the recorded working directory.

## Testing

Commands run to validate:

```sh
python3 -m py_compile scripts/agent-sudo-request.py scripts/agent-sudo-approve.py
./scripts/check-structure.sh
nix run .#agent-sudo-request -- --reason "test request" -- /usr/bin/true
nix run .#agent-sudo-approve -- --show <request-id>
nix run .#agent-sudo-approve -- --list
_AGENT_SUDO_ALLOW_SKIP_AUTH=1 ./scripts/agent-sudo-approve.py --skip-sudo-auth <request-id> # verified non-interactive refusal
./scripts/agent-sudo-approve.py /tmp/malicious.json # verified path requests are rejected
./scripts/agent-sudo-approve.py --show <symlink-request-id> # verified symlink requests are rejected
nix flake check --no-build
```

## Summary

### What changed

- Added `agent-sudo-request` flake app and script for creating request JSON files.
- Added `agent-sudo-approve` flake app and script for human inspection, confirmation, sudo authentication, execution, locking, and completion records.
- The request app can optionally open Terminal.app with the approval command.

### What was tested

- Python syntax compilation passed.
- Structure checks passed.
- Flake app evaluation passed.
- Request creation, request listing, and `--show` approval inspection worked.
- Non-interactive approval execution refused to proceed, preserving the human-confirmation requirement.
- Path-based request ids and symlink request files were rejected.
- `nix flake check --no-build` passed.
- Security review found no remaining blockers after hardening.

### Follow-up

- Backlog: add stale-lock recovery and cleanup for request files.
