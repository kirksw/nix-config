# Agent OS Pi Extension

Native Pi commands for the git-backed Agent OS workspace. Markdown thread, task, and run files remain the source of truth; JSONL is only the runtime store and mailbox transport.

## Modes

Mode is inferred from the active binding:

- **OS** — no thread is selected.
- **Thread** — a thread is selected without a task.
- **Factory** — a thread and task are selected.

`/agent-os status` is visible in every mode and reports mode, thread, task, and unread mailbox count.

## Commands

- `/agent-os status`
- `/agent-os thread <slug>`
- `/agent-os task [id|path|clear|spar <title>]` (alias: `/agent-os task`)
- `/agent-os new-thread <title> --kind <kind>`
- `/agent-os capture [text]`
- `/agent-os focus`
- `/agent-os render`
- `/agent-os promote <thread> <task>` (confirm Factory artifact → wiki)
- `/agent-os inbox`
- `/agent-os send --to <OS|Thread|Factory> [--thread slug] [--task id-or-path] <message>`
- `/agent-os ack <message-id|all>`
- `/agent-os todo add <text>`, `/agent-os todo done <number|text>`, `/agent-os todo list`
- `/agent-os reconcile [<slug>]`

Tasks must be files below `workspace/threads/<thread>/tasks`. `/agent-os task` is the shorthand alias. With no arguments it opens the same fuzzy TUI block as `/agent-os thread`: select a non-closed task, or select `✦ spar / create draft` and enter a title. An id is read from `id:`, `task:`, or the filename. A binding is persisted as a Pi `agent-os-binding` session entry and restored on reload. From an `*OS` repository inside Herdr, `/agent-os thread` opens a focused Herdr workspace and launches the selected thread there; outside Herdr it safely uses a replacement Pi session. Other repositories bind the current session.

## Launcher and Herdr workflow

The launcher resolves and validates both bindings before starting Pi:

```sh
agent-os launch --thread <slug> --task <id-or-path> --project /path/to/project
```

Herdr starts the launcher in the project Git root, then uses the resulting Pi pane/session as the durable worker context. Use `/agent-os status` to verify the selected mode and `/agent-os inbox` to inspect action-required messages. Herdr or another worker can send targeted messages through the shared runtime transport:

```text
workspace/runtime/os/{mailbox,events}.jsonl
workspace/runtime/threads/<thread>/{mailbox,events}.jsonl
workspace/runtime/threads/<thread>/tasks/<task>/{mailbox,events}.jsonl
```

Mailbox writes target the recipient scope. Inbox reads and acknowledgements use the active scope. Lifecycle events append to the active scope. These JSONL files are operational only; canonical decisions and work remain in Markdown.

## Tests

Run the full Agent OS suite from the repository root:

```sh
node --experimental-transform-types --import ./agents/packages/pi-subagents/test/support/register-loader.mjs --test agents/targets/pi/extensions/agent-os/tests/*.test.mjs
```

`migrateLegacyRuntime(workspacePath)` is an idempotent exported utility for moving supported records out of legacy `.lifeos/db` files. It reports unsupported non-empty records and removes the legacy directory only after a complete successful migration; it never creates Markdown records.

Todos route to `workspace/inbox/todos.md` in OS mode, an existing thread `todos.md` (otherwise the thread README manual area) in Thread mode, and the selected task file in Factory mode. Existing frontmatter and human-authored text are preserved.

## Scope and repo resolution

- personal scope uses `AGENT_OS_PERSONAL_REPO`, then `~/git/github.com/kirksw/lifeOS`
- lunar/work scope uses `AGENT_OS_WORK_REPO`, then `~/git/github.com/kirksw/lunarOS`
- unknown scopes disable writes rather than guessing

## ThreadOS and FactoryOS policy

The active binding is a capability boundary, not just a status label:

- **ThreadOS** (`Thread` mode) can read only `workspace/threads/<thread>/`. It may write thread-owned files, including `package.md`, `input/**`, the thread README, and thread notes. Factory-owned `runs/**` and `artifacts/**` are read-only.
- **FactoryOS** (`Factory` mode) can read only the selected task bundle. It may write only `runs/**` and `artifacts/**`; `package.md` and `input/**` are read-only ThreadOS inputs.
- Workspace path reads/writes through Pi `read`, `grep`, `find`, `ls`, `write`, and `edit` are blocked when they cross the boundary. Workspace shell access is blocked conservatively; project checkout access remains available for factory implementation.
- The extension also injects the active policy into the agent system prompt. A binding cannot switch its thread or task after launch.

Canonical task layout:

```text
workspace/threads/<thread>/tasks/<task>/
  package.md       # ThreadOS
  input/           # ThreadOS
  runs/            # FactoryOS
  artifacts/          # FactoryOS
```
