# ADR-001: Real-Time Multi-Team Dashboard as Pi TUI Extension

**Status:** Proposed  
**Date:** 2026-05-08

## Context

We need a real-time multi-team dashboard that displays team status, current updates, and activity logs within Pi's terminal UI. The dashboard must:

1. Show multiple teams simultaneously with status indicators (🟢 healthy / 🟡 degraded / 🔴 down).
2. Update in real-time by watching a shared JSON state file that external processes write to.
3. Support keyboard navigation to select a team and view its detailed activity log.
4. Be installable as a standalone Pi extension, invocable via `/team-dashboard`.

Pi's TUI system provides `Container`, `Box`, `Text`, `SelectList`, `DynamicBorder`, `Spacer`, and `Markdown` components with `ctx.ui.custom()` for full-screen custom UI. File watching follows the `fs.watch()` pattern established by `file-trigger.ts` in Pi's examples.

## Decision

Implement as a **Pi extension** at `agents/targets/pi/extensions/team-dashboard/index.ts` using:

- **Custom component** rendered via `ctx.ui.custom()` — owns the full terminal screen.
- **`fs.watch()` + `fs.watchFile()`** for real-time state file polling with fallback.
- **Two-panel layout**: team list (left/top) + detail panel (right/bottom), toggled by keyboard.
- **JSON state file** at `~/.config/team-dashboard/state.json` as the single source of truth.

### 1. Data Model

```typescript
// Types for team state — the shape of the JSON state file

type TeamStatus = "healthy" | "degraded" | "down";

interface ActivityEntry {
  timestamp: string;   // ISO 8601
  message: string;
  severity?: "info" | "warn" | "error";
}

interface TeamState {
  teamId: string;
  name: string;
  status: TeamStatus;
  currentUpdate: string;
  activityLog: ActivityEntry[];
  lastUpdated: string;  // ISO 8601
}

interface DashboardState {
  version: number;          // monotonic, incremented by writers
  updatedAt: string;        // ISO 8601
  teams: TeamState[];
}
```

### 2. State File Format

**Path:** `~/.config/team-dashboard/state.json`

```json
{
  "version": 42,
  "updatedAt": "2026-05-08T14:32:00Z",
  "teams": [
    {
      "teamId": "platform",
      "name": "Platform Infra",
      "status": "healthy",
      "currentUpdate": "Deploying v2.4.1 to staging",
      "activityLog": [
        { "timestamp": "2026-05-08T14:30:00Z", "message": "Started canary deploy", "severity": "info" },
        { "timestamp": "2026-05-08T14:31:00Z", "message": "Canary at 10% traffic", "severity": "info" }
      ],
      "lastUpdated": "2026-05-08T14:31:00Z"
    }
  ]
}
```

**Writer protocol:**
- External processes (CI, monitors, scripts) atomically write the file (write-to-temp + rename).
- The `version` field is incremented on each write; the dashboard skips re-parsing if version is unchanged.
- If the file doesn't exist, the dashboard shows an empty state with instructions.

### 3. Component Hierarchy

```
DashboardRoot (owns full screen)
├── DynamicBorder (top accent border)
├── Text (title bar: "Team Dashboard • N teams • last refresh")
├── DashboardBody
│   ├── TeamListView (left panel — always visible)
│   │   ├── Text ("Teams ↑↓ select • enter details • r refresh")
│   │   ├── TeamCard[] (one per team, selectable)
│   │   │   ├── Text (status emoji + team name)
│   │   │   ├── Text (current update, truncated to panel width)
│   │   │   └── Text (relative timestamp: "2m ago")
│   │   └── DynamicBorder (bottom separator)
│   └── DetailPanel (right panel — shown when team selected)
│       ├── DynamicBorder (accent border)
│       ├── Text (team name + status badge)
│       ├── Text ("Activity Log")
│       ├── ActivityLogView
│       │   └── Text[] (scrollable list of activity entries)
│       └── Text ("esc back • ↑↓ scroll")
└── DynamicBorder (bottom accent border)
```

**Key classes:**

| Component | Responsibility |
|-----------|---------------|
| `DashboardRoot` | Top-level component, owns `render()` / `handleInput()` / `invalidate()`. Manages file watcher lifecycle. Delegates to children. |
| `TeamListView` | Renders vertical list of `TeamCard`s. Tracks `selectedIndex`. Arrow keys change selection. |
| `TeamCard` | Renders a single team row: status emoji, name, current update, relative time. Highlighted when selected. |
| `DetailPanel` | Shows selected team's full activity log with scroll offset. Arrow keys scroll the log. |

### 4. File Watcher Integration

```typescript
class DashboardRoot {
  private watcher: fs.FSWatcher | null = null;
  private pollTimer: ReturnType<typeof setInterval> | null = null;
  private lastVersion = -1;

  startWatcher(tui: { requestRender: () => void }): void {
    const statePath = getStatePath(); // ~/.config/team-dashboard/state.json
    const dir = path.dirname(statePath);

    // Ensure directory exists
    fs.mkdirSync(dir, { recursive: true });

    // Primary: fs.watch for immediate feedback
    try {
      this.watcher = fs.watch(dir, (event, filename) => {
        if (filename === "state.json") this.reloadState(tui);
      });
    } catch {
      // Fallback: polling every 2s if fs.watch unavailable (NFS, etc.)
      this.pollTimer = setInterval(() => this.reloadState(tui), 2000);
    }

    // Also use watchFile as a safety net for in-place writes
    fs.watchFile(statePath, { interval: 2000 }, () => this.reloadState(tui));

    // Initial load
    this.reloadState(tui);
  }

  private reloadState(tui: { requestRender: () => void }): void {
    try {
      const raw = fs.readFileSync(getStatePath(), "utf-8");
      const state = JSON.parse(raw) as DashboardState;
      if (state.version !== this.lastVersion) {
        this.lastVersion = state.version;
        this.state = state;
        this.invalidate();
        tui.requestRender();
      }
    } catch {
      // File might not exist yet — keep previous state or show empty
    }
  }

  dispose(): void {
    this.watcher?.close();
    if (this.pollTimer) clearInterval(this.pollTimer);
    fs.unwatchFile(getStatePath());
  }
}
```

### 5. Keyboard Navigation

| Key | Context | Action |
|-----|---------|--------|
| `↑` / `k` | Team list | Move selection up |
| `↓` / `j` | Team list | Move selection down |
| `Enter` | Team list | Open detail panel for selected team |
| `Escape` | Detail panel open | Close detail panel, return to list |
| `↑` / `k` | Detail panel | Scroll activity log up |
| `↓` / `j` | Detail panel | Scroll activity log down |
| `r` | Any | Force reload state file |
| `q` | Detail panel closed | Quit dashboard |
| `Ctrl+C` | Any | Quit dashboard |

### 6. Rendering Layout

**Narrow terminal (< 80 cols):** Stacked layout — team list fills the width, detail panel replaces it (like a page navigation).

**Wide terminal (≥ 80 cols):** Side-by-side — team list takes ~35 cols, detail panel takes the rest. Uses `width` parameter in `render()` to adapt.

```typescript
render(width: number): string[] {
  const sideBySide = width >= 80;
  if (sideBySide) {
    // Split: left 35 chars for team list, right for detail
    const leftWidth = 35;
    const rightWidth = width - leftWidth - 1; // -1 for separator
    return this.renderSideBySide(leftWidth, rightWidth);
  } else {
    return this.renderStacked(width);
  }
}
```

### 7. Extension Registration

The extension registers a `/team-dashboard` command:

```typescript
export default function (pi: ExtensionAPI) {
  pi.registerCommand("team-dashboard", {
    description: "Real-time multi-team status dashboard",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("Dashboard requires interactive mode", "error");
        return;
      }

      await ctx.ui.custom<void>((tui, theme, _kb, done) => {
        const dashboard = new DashboardRoot(tui, theme, done);
        dashboard.startWatcher(tui);
        return dashboard; // { render, invalidate, handleInput }
      });
    },
  });
}
```

### 8. Project File Structure

```
agents/targets/pi/extensions/team-dashboard/
├── index.ts              # Extension entry point — registers /team-dashboard command
├── types.ts              # DashboardState, TeamState, ActivityEntry types
├── components/
│   ├── dashboard-root.ts # DashboardRoot — top-level component + file watcher
│   ├── team-list.ts      # TeamListView — team selector with TeamCard rows
│   ├── team-card.ts      # TeamCard — single team row rendering
│   └── detail-panel.ts   # DetailPanel — expanded activity log view
└── utils/
    ├── state-reader.ts   # readStateFile(), getStatePath()
    └── time.ts           # relativeTime() for "2m ago" formatting
```

### 9. Status Emoji Mapping

```typescript
function statusEmoji(status: TeamStatus): string {
  switch (status) {
    case "healthy":  return "🟢";
    case "degraded": return "🟡";
    case "down":     return "🔴";
  }
}

function statusColor(theme: Theme, status: TeamStatus): (s: string) => string {
  switch (status) {
    case "healthy":  return (s) => theme.fg("success", s);
    case "degraded": return (s) => theme.fg("warning", s);
    case "down":     return (s) => theme.fg("error", s);
  }
}
```

## Consequences

### Positive
- **Zero network dependency** — file-based state is the simplest possible integration; any language/tool can write JSON.
- **Atomic updates** — write-to-temp + rename ensures the dashboard never reads a partial file.
- **Responsive layout** — adapts to terminal width, usable from small terminals to wide desktops.
- **Theme-aware** — uses Pi's `theme.fg()`/`theme.bg()` for all styling, respects theme changes.
- **Session-compatible** — runs as a Pi command, coexists with normal Pi workflow; `Ctrl+C` or `q` returns to normal Pi UI.

### Negative
- **Polling overhead** — `fs.watch()` + `fs.watchFile()` fallback means up to 2s delay on some platforms. Acceptable for team status (not millisecond-critical).
- **No multi-writer coordination** — if multiple writers update simultaneously, last-write-wins. The `version` field mitigates stale reads but doesn't prevent lost updates. A future enhancement could use advisory file locking (`flock`).
- **Emoji rendering** — status emojis depend on terminal font support. Fallback to ASCII (`[OK]`, `[!!]`, `[XX]`) if detection is needed.

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `fs.watch()` not firing on network filesystems | Medium | Stale UI | `fs.watchFile()` fallback polls every 2s |
| State file grows unbounded (large activity logs) | Low | Slow parse | Cap activity log to last 100 entries per team in the reader |
| Terminal too narrow for side-by-side | Low | Layout breaks | Stacked layout below 80 cols |
| File deleted while dashboard open | Low | Error | Catch ENOENT, show "Waiting for state file…" placeholder |

## Conformance Criteria

1. `/team-dashboard` command opens a full-screen TUI dashboard in Pi.
2. Dashboard reads and renders `~/.config/team-dashboard/state.json`.
3. File changes are reflected within 2 seconds.
4. Arrow keys navigate team selection; Enter opens detail panel; Escape closes it.
5. Detail panel shows full scrollable activity log for the selected team.
6. `q` or `Ctrl+C` exits the dashboard and returns to normal Pi UI.
7. All colors use `theme.fg()`/`theme.bg()` — no hardcoded ANSI codes for status colors.
8. `invalidate()` properly clears caches on state change and theme change.
9. File watcher is cleaned up (`dispose()`) when dashboard closes.
10. Works correctly at 60-column and 120-column terminal widths.

## Implementation Plan

| Phase | Scope | Effort |
|-------|-------|--------|
| **P1** | Types, state reader, `DashboardRoot` with team list only | S (2-3h) |
| **P2** | `DetailPanel` with scrollable activity log | S (2h) |
| **P3** | Responsive layout (side-by-side vs stacked) | S (1-2h) |
| **P4** | File watcher with `fs.watch()` + fallback, force-refresh | S (1-2h) |
| **P5** | Theme-aware styling, edge cases (missing file, empty state) | S (1-2h) |

**Total estimated effort:** M (half day)

### Rollout
1. Place extension at `agents/targets/pi/extensions/team-dashboard/`.
2. Wire into the Nix build (the existing auto-discovery in `agents/targets/pi/extensions/` handles this).
3. Test with `pi -e agents/targets/pi/extensions/team-dashboard/index.ts`.
4. Once stable, add to the persistent extension set in the Nix config.
5. Create a companion script (`scripts/team-dashboard-writer.sh`) for demo/testing that writes sample state.

### Example Writer Script (for testing)

```bash
#!/usr/bin/env bash
# scripts/team-dashboard-writer.sh — writes sample state to the dashboard state file
STATE_DIR="$HOME/.config/team-dashboard"
STATE_FILE="$STATE_DIR/state.json"
mkdir -p "$STATE_DIR"

TMP=$(mktemp)
cat > "$TMP" << 'EOF'
{
  "version": 1,
  "updatedAt": "TIMESTAMP",
  "teams": [
    {
      "teamId": "platform",
      "name": "Platform Infra",
      "status": "healthy",
      "currentUpdate": "All systems nominal",
      "activityLog": [
        {"timestamp": "TIMESTAMP", "message": "Health check passed", "severity": "info"}
      ],
      "lastUpdated": "TIMESTAMP"
    },
    {
      "teamId": "frontend",
      "name": "Frontend",
      "status": "degraded",
      "currentUpdate": "Investigating slow page loads",
      "activityLog": [
        {"timestamp": "TIMESTAMP", "message": "P95 latency above threshold", "severity": "warn"},
        {"timestamp": "TIMESTAMP", "message": "On-call paged", "severity": "info"}
      ],
      "lastUpdated": "TIMESTAMP"
    },
    {
      "teamId": "data",
      "name": "Data Pipeline",
      "status": "down",
      "currentUpdate": "Kafka cluster unreachable",
      "activityLog": [
        {"timestamp": "TIMESTAMP", "message": "Connection refused to broker-0", "severity": "error"},
        {"timestamp": "TIMESTAMP", "message": "Auto-scaler triggered", "severity": "info"}
      ],
      "lastUpdated": "TIMESTAMP"
    }
  ]
}
EOF

# Replace timestamps
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
sed -i "s/TIMESTAMP/$NOW/g" "$TMP"
mv "$TMP" "$STATE_FILE"
echo "State written to $STATE_FILE"
```
