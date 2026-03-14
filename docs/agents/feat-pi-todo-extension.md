# feat-pi-todo-extension

> Add todo management extension to PI agent with branch-aware state reconstruction.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [ ] Complete

## Context

PI coding agent needs a todo management extension to demonstrate state management via session entries. This allows the agent to track tasks across session branches without external file dependencies. The extension provides both a tool for the LLM and a user command for viewing todos.

## Plan

### Scope

Files affected:
- `agents/pi/extensions/todo/index.ts` (new)
- `docs/agents/feat-pi-todo-extension.md` (new)

### Approach

1. Create `agents/pi/extensions/todo/` directory structure
2. Implement todo extension with:
   - In-memory state (`todos`, `nextId`)
   - State reconstruction from session branch history
   - Tool registration with `list|add|toggle|clear` actions
   - Parameter validation (text for add, id for toggle)
   - Details snapshots on every action for branch replay
3. Add session event handlers:
   - `session_start`
   - `session_switch`
   - `session_fork`
   - `session_tree`
4. Implement `/todos` command with:
   - Interactive UI via `ctx.ui.custom` when available
   - Safe non-interactive no-op fallback
5. Add custom rendering for tool calls and results
6. Create feature plan document following repo template

### Risks

- State reconstruction depends on `details` being preserved in session history
- Non-interactive fallback may not render as nicely as interactive UI
- Extension must be manually loaded by PI agent configuration

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
pi --mode json -p --no-session -e ~/.pi/agent/extensions/todo/index.ts "Use the todo tool only. Add todo 'alpha', add todo 'beta', list todos, toggle id 1, list todos, clear todos, then list todos and report the final list."
pi --mode json -p --session /tmp/pi-todo-smoke.jsonl -e ~/.pi/agent/extensions/todo/index.ts "Use todo tool only: add todo 'persist me' and then list todos."
pi --mode json -p --session /tmp/pi-todo-smoke.jsonl -e ~/.pi/agent/extensions/todo/index.ts "Use the todo tool only and list todos."
```

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._

### What changed

- Created todo extension at `agents/pi/extensions/todo/index.ts`
- Added feature plan document
- Implemented branch-aware state management
- Added interactive `/todos` UI with safe non-interactive behavior

### What was tested

- Structure validation
- Flake checks
- Syncing assets into `~/.pi/agent`
- Non-interactive tool smoke test (`add`, `list`, `toggle`, `clear`) ending with `No todos`
- Session reconstruction across separate invocations using the same `--session` file (`persist me` remained listed)

### Follow-up

- Test extension in live PI TUI session for `/todos` rendering and branch fork/switch replay behavior.
