---
name: herdr
description: Use herdr reliably from pi when HERDR_ENV/HERDR_PANE_ID indicate this agent is running inside herdr. Organize panes, tabs, workspaces, long-running commands, dev servers, test panes, or sibling pi/agent panes with the native herdr tool.
---

# herdr

Before doing herdr work, check whether the native `herdr` tool is available. If it is missing, only use CLI fallback when `HERDR_ENV=1` and `HERDR_PANE_ID` is set.

## Native pi tool pattern

Prefer the pi `herdr` tool over `bash herdr ...`.

If the user names a workspace/project/thread (`dwh-4261`, repo name, ticket, etc.), target that workspace first:

1. Call `{ "action": "workspace_list" }` and match labels case-insensitively.
2. If the workspace exists, create a tab/root pane inside it:
   - `{ "action": "tab_create", "workspace": "wW", "label": "pi", "pane": "dwh4261-pi" }`
3. If it does not exist and a cwd is known, create it:
   - `{ "action": "workspace_create", "label": "dwh-4261", "cwd": "/path", "pane": "dwh4261-pi" }`
   `workspace_create` already creates the default tab and root pane; do not create a second tab. Reuse the returned root pane.
4. When descriptive tab/pane labels are wanted, get the qualified tab id with `{ "action": "tab_list", "workspace": "wW" }`, then use the CLI because the native tool has no rename action:
   - `herdr tab rename <tab-id> <label>`
   - `herdr pane rename <root-pane-id> <label>`
5. Native pane actions are scoped to the Pi agent's own workspace. `workspace_focus`/`tab_focus` change UI focus only; they do not change that scope. For a root pane in another workspace, use the CLI instead:
   - Run: `herdr pane run <root-pane-id> "pi --no-session"`
   - Read: `herdr pane read <root-pane-id> --source recent-unwrapped --lines 80`
   - Wait: `herdr wait agent-status <root-pane-id> --status idle --timeout 30000`
   Do not retry native `list`, pane `focus`, `run`, `read`, `watch`, `wait_agent`, `send`, `stop`, or `pane_split` for that pane after changing focus.

Only split the current pane when the user asks for a split/right/below pane, or when no target workspace is named:

1. Create or select a pane.
   - Split current pane: `{ "action": "pane_split", "newPane": "server" }`
   - New tab root pane in current workspace: `{ "action": "tab_create", "label": "server", "pane": "server" }`
   - New workspace root pane: `{ "action": "workspace_create", "label": "api", "pane": "api", "cwd": "/path" }`
2. Run in that pane: `{ "action": "run", "pane": "server", "command": "npm run dev" }` (for a pane in another workspace, use the CLI workflow above for all pane actions).
3. Wait/read by pane alias in the agent's own workspace:
   - Normal process: `{ "action": "watch", "pane": "server", "match": "ready|listening", "regex": true }`
   - Logs: `{ "action": "read", "pane": "server", "source": "recent-unwrapped", "lines": 80 }`
   - Agent pane only: `{ "action": "wait_agent", "pane": "reviewer", "statuses": ["idle", "done"] }`

## Rules

- Pane actions (`run`, `read`, `watch`, `wait_agent`, `send`, `stop`) require a pane alias or real pane id, not a workspace id or tab id.
- `run` never creates a pane. Create/split first, then run.
- Do not use `pane_split` to target another workspace. Use `tab_create` with `workspace`, or `workspace_create`.
- Prefer friendly aliases (`server`, `tests`, `reviewer`) and reuse them.
- Use `run` for text plus Enter. Use `send` only for raw text/keys without implicit Enter.
- Use `watch` for servers, tests, builds, and logs. Use `wait_agent` only for recognized coding agents.
- Preserve focus unless the user explicitly asks to switch: omit `focus` or set `focus: false`. Focus changes do not change the workspace scope of native pane actions.
- Use `source: "recent-unwrapped"` when matching or reading logs that may soft-wrap.
- If an alias is stale, call `list`, pick a live pane id, or create a fresh pane. Do not guess ids.

## CLI fallback

```bash
[ "$HERDR_ENV" = 1 ] && [ -n "$HERDR_PANE_ID" ] || exit 1
NEW_PANE=$(herdr pane split "$HERDR_PANE_ID" --direction right --no-focus \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "npm run dev"
herdr wait output "$NEW_PANE" --match "ready" --timeout 30000
herdr pane read "$NEW_PANE" --source recent-unwrapped --lines 80
```
