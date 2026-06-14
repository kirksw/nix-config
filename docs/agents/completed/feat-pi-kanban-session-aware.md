# feat-pi-kanban-session-aware

> Make pi-kanban aware of nix-agents Pi session profiles and support parallel Personal/Work dashboards.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`pi-kanban` only scanned `~/.pi/agent/sessions/<project>/*.jsonl`. This missed current sessions created by the nix-agents Pi wrapper under `~/.local/share/nix-agents/pi/sessions/<profile>/*.jsonl`, and symlinked profile directories were ignored because the parser filtered with `Dirent.isDirectory()`.

The operator also needs separate Personal and Work dashboards running at the same time, with a clear dashboard title at the top.

## Plan

### Scope

- `agents/external/pi-packages/patches/pi-kanban/`
- `flake/apps.nix`
- Local installed `pi-kanban` package copies under personal/work Pi profiles.

### Approach

1. Patch `pi-kanban` session discovery to honor `KANBAN_SESSION_DIRS` and `PI_CODING_AGENT_SESSION_DIR`.
2. Support both direct-profile JSONL layouts and legacy nested project directory layouts, following symlinked dirs/files via `fs.stat`.
3. Add dashboard metadata (`dashboardTitle`, `sessionDirs`) to `/api/version` and render the title in the sidebar logo/document title.
4. Allow `limit=all` server-side so the existing UI option works.
5. Extend `/kanban` commands to launch `personal` and `work` dashboards in parallel on ports `3460` and `3461`.
6. Preserve the patch through `sync-agents` by copying patched files over installed profile packages after package sync.

### Risks

- This is a local vendor patch over `pi-kanban@1.0.0`; upstream package changes may require refreshing the patch files.
- Session-scoped commands still target the current profile dashboard by default.

## Testing

Commands run to validate:

```sh
node --check ~/.config/nix-agents/pi/bases/personal/profiles/personal-default/npm/node_modules/pi-kanban/lib/pi-parsers.js
node --check ~/.config/nix-agents/pi/bases/personal/profiles/personal-default/npm/node_modules/pi-kanban/server.js
PI_CODING_AGENT_SESSION_DIR=~/.local/share/nix-agents/pi/sessions/personal-default node -e '... parsers.listSessions() ...'
PI_CODING_AGENT_SESSION_DIR=~/.local/share/nix-agents/pi/sessions/work-default node -e '... parsers.listSessions() ...'
PORT=3460 KANBAN_DASHBOARD_TITLE='Personal Dashboard' KANBAN_SESSION_DIRS=~/.local/share/nix-agents/pi/sessions/personal-default node server.js
PORT=3461 KANBAN_DASHBOARD_TITLE='Work Dashboard' KANBAN_SESSION_DIRS=~/.local/share/nix-agents/pi/sessions/work-default node server.js
curl http://localhost:3460/api/sessions?limit=all
curl http://localhost:3461/api/sessions?limit=all
```

## Summary

### What changed

- Patched session discovery to read nix-agents profile session directories directly.
- Added parallel Personal/Work dashboards:
  - Personal Dashboard: `http://localhost:3460`
  - Work Dashboard: `http://localhost:3461`
- Added dashboard title metadata and UI title rendering.
- Fixed `limit=all` handling.
- Wired `sync-agents` to reapply the local pi-kanban patch.

### What was tested

- Personal dashboard returned 16 sessions from `personal-default`.
- Work dashboard returned 21 sessions from `work-default`.
- Both servers ran concurrently and exposed the correct dashboard title/session directory via `/api/version`.

### Follow-up

- Upstream these changes to `pi-kanban` or replace the local vendor patch after upstream supports configurable session roots.
