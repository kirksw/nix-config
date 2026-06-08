# feat-pi-session-dir

> Keep Pi session JSONL files out of generated profile config directories.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi freezes with repeated `ENOENT` errors opening session JSONL files under
`~/.config/nix-agents/pi/bases/<base>/profiles/<profile>/sessions/...`.
The nix-agents Pi wrapper syncs the generated profile directory at launch, and nested
Pi invocations can remove `profile/sessions` while a parent Pi process is still using
a session file there.

## Plan

### Scope

- `modules/home/programs/ai-agents.nix`
- Pi wrapper runtime behavior only

### Approach

1. Export `PI_CODING_AGENT_SESSION_DIR` from the outer Home Manager Pi wrapper.
2. Store sessions under `~/.local/share/nix-agents/pi/sessions/<profile>`.
3. Keep credential/profile behavior unchanged.
4. Validate the Nix module and wrapper behavior.

### Risks

Pi sessions are now grouped by profile instead of by generated profile config directory.
Pi records and filters session cwd in the session header, so project-local resume should
continue to work.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
XDG_DATA_HOME="$(mktemp -d /private/tmp/pi-data.XXXXXX)" /nix/store/71azdywn99h6709fgs9ivfb24h0hapyf-pi/bin/pi --help
```

## Summary

### What changed

- The Pi Home Manager credential wrapper now resolves the active nix-agents profile
  and exports `PI_CODING_AGENT_SESSION_DIR` to
  `~/.local/share/nix-agents/pi/sessions/<profile>`.
- This keeps live Pi JSONL session files out of generated profile config directories
  that nested Pi wrapper launches may sync.

### What was tested

- `./scripts/check-structure.sh` passed.
- `nix flake check --no-build` passed.
- `nix run .#sync-agents` failed because this flake does not currently define a
  `sync-agents` app or package.
- Built far enough to realize the new Pi wrapper at `/nix/store/71azdywn99h6709fgs9ivfb24h0hapyf-pi`.
- Full Darwin generation build is blocked by unrelated `ollama` failure requiring
  Xcode's Metal toolchain.
- The generated Pi wrapper starts with `--help` and creates
  `nix-agents/pi/sessions/personal-default` under a temporary `XDG_DATA_HOME`.

### Follow-up

- Add an upstream nix-agents wrapper fix so Pi wrappers never delete or copy live session directories.
