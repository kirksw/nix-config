/**
 * Team Dashboard Extension
 *
 * Real-time multi-team status dashboard as a Pi TUI extension.
 * Reads state from ~/.config/team-dashboard/state.json and watches
 * for changes to provide live updates.
 *
 * Usage: /team-dashboard
 *
 * Layout:
 *   Wide (>=80 cols): side-by-side (team list | detail panel)
 *   Narrow (<80 cols): stacked (detail replaces list)
 *
 * Keyboard:
 *   ↑/k  move up      ↓/j  move down
 *   Enter  open detail  Escape  close detail / quit
 *   r  force reload    q  quit (when detail closed)
 *   Ctrl+C  quit
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI, Theme } from "@mariozechner/pi-coding-agent";
import { matchesKey, Key, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type TeamStatus = "healthy" | "degraded" | "down";

interface ActivityEntry {
  timestamp: string;
  message: string;
  severity?: "info" | "warn" | "error";
}

interface TeamState {
  teamId: string;
  name: string;
  status: TeamStatus;
  currentUpdate: string;
  activityLog: ActivityEntry[];
  lastUpdated: string;
}

interface DashboardState {
  version: number;
  updatedAt: string;
  teams: TeamState[];
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

function getStatePath(): string {
  return path.join(os.homedir(), ".config", "team-dashboard", "state.json");
}

function readStateFile(): DashboardState | null {
  try {
    const raw = fs.readFileSync(getStatePath(), "utf-8");
    const state = JSON.parse(raw) as DashboardState;
    // Cap activity logs to 100 entries per team
    for (const team of state.teams) {
      if (team.activityLog.length > 100) {
        team.activityLog = team.activityLog.slice(0, 100);
      }
    }
    return state;
  } catch {
    return null;
  }
}

function relativeTime(iso: string): string {
  try {
    const then = new Date(iso).getTime();
    const now = Date.now();
    const diffSec = Math.max(0, Math.floor((now - then) / 1000));
    if (diffSec < 60) return "just now";
    if (diffSec < 3600) return `${Math.floor(diffSec / 60)}m ago`;
    if (diffSec < 86400) return `${Math.floor(diffSec / 3600)}h ago`;
    return `${Math.floor(diffSec / 86400)}d ago`;
  } catch {
    return "";
  }
}

function statusEmoji(status: TeamStatus): string {
  switch (status) {
    case "healthy":
      return "🟢";
    case "degraded":
      return "🟡";
    case "down":
      return "🔴";
  }
}

function statusFg(theme: Theme, status: TeamStatus): (s: string) => string {
  switch (status) {
    case "healthy":
      return (s) => theme.fg("success", s);
    case "degraded":
      return (s) => theme.fg("warning", s);
    case "down":
      return (s) => theme.fg("error", s);
  }
}

function severityIcon(severity?: string): string {
  switch (severity) {
    case "error":
      return "✕";
    case "warn":
      return "⚠";
    default:
      return "·";
  }
}

function severityFg(theme: Theme, severity?: string): (s: string) => string {
  switch (severity) {
    case "error":
      return (s) => theme.fg("error", s);
    case "warn":
      return (s) => theme.fg("warning", s);
    default:
      return (s) => theme.fg("dim", s);
  }
}

// Pad a string to a given visible width, truncating if too long.
function padOrTruncate(text: string, width: number, padChar = " "): string {
  const vw = visibleWidth(text);
  if (vw > width) return truncateToWidth(text, width);
  if (vw < width) return text + padChar.repeat(width - vw);
  return text;
}

// ---------------------------------------------------------------------------
// DashboardRoot — top-level component
// ---------------------------------------------------------------------------

type ViewMode = "list" | "detail";

interface TuiHandle {
  requestRender(): void;
}

class DashboardRoot {
  private theme: Theme;
  private done: () => void;
  private tui: TuiHandle;

  // State
  private state: DashboardState | null = null;
  private lastVersion = -1;
  private selectedIndex = 0;
  private viewMode: ViewMode = "list";
  private detailScrollOffset = 0;
  private loadError = false;

  // File watching
  private watcher: fs.FSWatcher | null = null;
  private pollTimer: ReturnType<typeof setInterval> | null = null;

  // Render cache
  private cachedWidth?: number;
  private cachedLines?: string[];

  constructor(tui: TuiHandle, theme: Theme, done: () => void) {
    this.tui = tui;
    this.theme = theme;
    this.done = done;
  }

  // ---- File watcher ----

  startWatcher(): void {
    const statePath = getStatePath();
    const dir = path.dirname(statePath);
    fs.mkdirSync(dir, { recursive: true });

    // Primary: fs.watch on the directory
    try {
      this.watcher = fs.watch(dir, () => {
        this.reloadState();
      });
    } catch {
      // Fallback: polling
      this.pollTimer = setInterval(() => this.reloadState(), 2000);
    }

    // Safety net: watchFile for in-place writes
    try {
      fs.watchFile(statePath, { interval: 2000 }, () => {
        this.reloadState();
      });
    } catch {
      // ignore
    }

    // Initial load
    this.reloadState();
  }

  dispose(): void {
    this.watcher?.close();
    if (this.pollTimer) clearInterval(this.pollTimer);
    try {
      fs.unwatchFile(getStatePath());
    } catch {
      // ignore
    }
  }

  private reloadState(): void {
    const state = readStateFile();
    this.loadError = state === null;
    if (state && state.version !== this.lastVersion) {
      this.lastVersion = state.version;
      this.state = state;
      // Clamp selection
      if (this.selectedIndex >= state.teams.length) {
        this.selectedIndex = Math.max(0, state.teams.length - 1);
      }
      this.invalidate();
      this.tui.requestRender();
    }
  }

  // ---- Keyboard ----

  handleInput(data: string): void {
    if (matchesKey(data, Key.ctrl("c"))) {
      this.done();
      return;
    }

    if (this.viewMode === "detail") {
      this.handleDetailInput(data);
    } else {
      this.handleListInput(data);
    }
  }

  private handleListInput(data: string): void {
    const teams = this.state?.teams ?? [];

    if (matchesKey(data, Key.up) || data === "k") {
      if (this.selectedIndex > 0) {
        this.selectedIndex--;
        this.invalidate();
        this.tui.requestRender();
      }
    } else if (matchesKey(data, Key.down) || data === "j") {
      if (this.selectedIndex < teams.length - 1) {
        this.selectedIndex++;
        this.invalidate();
        this.tui.requestRender();
      }
    } else if (matchesKey(data, Key.enter)) {
      if (teams.length > 0) {
        this.viewMode = "detail";
        this.detailScrollOffset = 0;
        this.invalidate();
        this.tui.requestRender();
      }
    } else if (data === "r") {
      this.lastVersion = -1;
      this.reloadState();
    } else if (data === "q") {
      this.done();
    }
  }

  private handleDetailInput(data: string): void {
    const teams = this.state?.teams ?? [];
    const team = teams[this.selectedIndex];
    const logLength = team?.activityLog.length ?? 0;

    if (matchesKey(data, Key.escape)) {
      this.viewMode = "list";
      this.invalidate();
      this.tui.requestRender();
    } else if (matchesKey(data, Key.up) || data === "k") {
      if (this.detailScrollOffset > 0) {
        this.detailScrollOffset--;
        this.invalidate();
        this.tui.requestRender();
      }
    } else if (matchesKey(data, Key.down) || data === "j") {
      const logLength = team?.activityLog.length ?? 0;
      const maxOffset = Math.max(0, logLength - 20);
      if (this.detailScrollOffset < maxOffset) {
        this.detailScrollOffset++;
        this.invalidate();
        this.tui.requestRender();
      }
    } else if (data === "r") {
      this.lastVersion = -1;
      this.reloadState();
    }
  }

  // ---- Rendering ----

  render(width: number): string[] {
    if (this.cachedLines && this.cachedWidth === width) {
      return this.cachedLines;
    }

    const th = this.theme;
    const lines: string[] = [];

    // Title bar
    const teamCount = this.state?.teams.length ?? 0;
    const lastRefresh = this.state?.updatedAt ? relativeTime(this.state.updatedAt) : "never";
    const titleText = ` Team Dashboard `;
    const titleInfo = ` ${teamCount} team${teamCount !== 1 ? "s" : ""} · ${lastRefresh} `;
    const titlePad = Math.max(0, width - visibleWidth(titleText) - visibleWidth(titleInfo));
    const titleLine = th.fg("accent", th.bold(titleText)) + " ".repeat(titlePad) + th.fg("dim", titleInfo);
    lines.push(truncateToWidth(titleLine, width));
    lines.push(th.fg("borderMuted", "─".repeat(width)));

    if (this.loadError && !this.state) {
      lines.push("");
      lines.push(truncateToWidth(`  ${th.fg("dim", "Waiting for state file...")}`, width));
      lines.push(truncateToWidth(`  ${th.fg("dim", `Create: ${getStatePath()}`)}`, width));
      lines.push("");
    } else if (teamCount === 0) {
      lines.push("");
      lines.push(truncateToWidth(`  ${th.fg("dim", "No teams configured")}`, width));
      lines.push("");
    } else if (this.viewMode === "detail") {
      this.renderDetail(lines, width);
    } else if (width >= 80) {
      this.renderSideBySide(lines, width);
    } else {
      this.renderStackedList(lines, width);
    }

    // Footer
    lines.push(th.fg("borderMuted", "─".repeat(width)));
    if (this.viewMode === "detail") {
      lines.push(
        truncateToWidth(
          `  ${th.fg("dim", "↑↓ scroll")}  ${th.fg("dim", "r reload")}  ${th.fg("dim", "esc back")}  ${th.fg("dim", "ctrl+c quit")}`,
          width,
        ),
      );
    } else {
      lines.push(
        truncateToWidth(
          `  ${th.fg("dim", "↑↓ navigate")}  ${th.fg("dim", "enter details")}  ${th.fg("dim", "r reload")}  ${th.fg("dim", "q quit")}`,
          width,
        ),
      );
    }

    this.cachedWidth = width;
    this.cachedLines = lines;
    return lines;
  }

  // ---- Side-by-side layout (>=80 cols) ----

  private renderSideBySide(lines: string[], width: number): void {
    const th = this.theme;
    const teams = this.state!.teams;
    const listWidth = Math.min(38, Math.floor(width * 0.4));
    const sep = th.fg("borderMuted", "│");
    const detailWidth = Math.max(0, width - listWidth - 1); // -1 for separator

    // Team list lines
    const listLines = this.renderTeamList(teams, listWidth);

    // Detail lines for selected team
    const selectedTeam = teams[this.selectedIndex];
    const detailLines = selectedTeam ? this.renderDetailPanel(selectedTeam, detailWidth) : [];

    // Zip together
    const maxLines = Math.max(listLines.length, detailLines.length, 1);
    for (let i = 0; i < maxLines; i++) {
      const left = i < listLines.length ? listLines[i]! : "";
      const right = i < detailLines.length ? detailLines[i]! : "";
      lines.push(padOrTruncate(left, listWidth) + sep + truncateToWidth(right, detailWidth));
    }
  }

  // ---- Stacked layout (<80 cols) ----

  private renderStackedList(lines: string[], width: number): void {
    const th = this.theme;
    const teams = this.state!.teams;

    const listLines = this.renderTeamList(teams, width);
    lines.push(...listLines);
  }

  // ---- Team list rendering ----

  private renderTeamList(teams: TeamState[], width: number): string[] {
    const th = this.theme;
    const lines: string[] = [];

    for (let i = 0; i < teams.length; i++) {
      const team = teams[i]!;
      const selected = i === this.selectedIndex;
      const emoji = statusEmoji(team.status);
      const name = selected ? th.fg("accent", th.bold(team.name)) : th.fg("text", team.name);

      // First line: emoji + name
      const prefix = selected ? th.bg("selectedBg", " ") : " ";
      const line1 = prefix + " " + emoji + " " + name;
      lines.push(truncateToWidth(line1, width));

      // Second line: current update (truncated)
      const update = team.currentUpdate || th.fg("dim", "No update");
      const updateText = selected ? th.fg("accent", update) : th.fg("muted", update);
      const line2 = "     " + truncateToWidth(updateText, width - 5);
      lines.push(truncateToWidth(line2, width));

      // Third line: relative time
      const timeStr = team.lastUpdated ? relativeTime(team.lastUpdated) : "";
      const line3 = "     " + th.fg("dim", timeStr);
      lines.push(truncateToWidth(line3, width));

      // Spacing between teams
      if (i < teams.length - 1) {
        lines.push("");
      }
    }

    return lines;
  }

  // ---- Detail panel rendering (inline for detail viewMode) ----

  private renderDetail(lines: string[], width: number): void {
    const teams = this.state!.teams;
    const team = teams[this.selectedIndex];
    if (!team) return;

    const detailLines = this.renderDetailPanel(team, width);
    lines.push(...detailLines);
  }

  // ---- Detail panel rendering (reusable) ----

  private renderDetailPanel(team: TeamState, width: number): string[] {
    const th = this.theme;
    const lines: string[] = [];

    // Header: team name + status
    const emoji = statusEmoji(team.status);
    const statusLabel = statusFg(th, team.status)(`[${team.status}]`);
    const header = ` ${emoji} ${th.fg("accent", th.bold(team.name))}  ${statusLabel}`;
    lines.push(truncateToWidth(header, width));

    // Current update
    if (team.currentUpdate) {
      lines.push(truncateToWidth(`   ${th.fg("text", team.currentUpdate)}`, width));
    }

    // Relative time
    const timeStr = team.lastUpdated ? relativeTime(team.lastUpdated) : "";
    lines.push(truncateToWidth(`   ${th.fg("dim", timeStr)}`, width));

    lines.push(th.fg("borderMuted", " " + "─".repeat(Math.max(0, width - 2))));

    // Activity log header
    lines.push(truncateToWidth(`  ${th.fg("muted", th.bold("Activity Log"))}`, width));
    lines.push("");

    // Activity log entries
    const log = team.activityLog;
    if (log.length === 0) {
      lines.push(truncateToWidth(`  ${th.fg("dim", "No activity recorded")}`, width));
    } else {
      // Apply scroll offset
      const maxVisible = 20; // reasonable display limit
      const offset = Math.min(this.detailScrollOffset, Math.max(0, log.length - maxVisible));
      const visible = log.slice(offset, offset + maxVisible);

      for (const entry of visible) {
        const icon = severityIcon(entry.severity);
        const time = entry.timestamp ? relativeTime(entry.timestamp) : "";
        const timeStr2 = th.fg("dim", `${time}`.padEnd(8));
        const msgColor = severityFg(th, entry.severity);
        const line = `  ${msgColor(icon)} ${timeStr2} ${th.fg("text", entry.message)}`;
        lines.push(truncateToWidth(line, width));
      }

      // Scroll indicator
      if (log.length > maxVisible) {
        const position = `${offset + 1}-${Math.min(offset + maxVisible, log.length)} of ${log.length}`;
        lines.push("");
        lines.push(truncateToWidth(`  ${th.fg("dim", position)}`, width));
      }
    }

    return lines;
  }

  // ---- Cache ----

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedLines = undefined;
  }
}

// ---------------------------------------------------------------------------
// Extension registration
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  pi.registerCommand("team-dashboard", {
    description: "Real-time multi-team status dashboard",
    handler: async (_args, ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("Dashboard requires interactive mode", "warning");
        return;
      }

      let dashboard: DashboardRoot | null = null;

      try {
        await ctx.ui.custom<void>((tui, theme, _kb, done) => {
          dashboard = new DashboardRoot(tui, theme, done);
          dashboard.startWatcher();
          return dashboard;
        });
      } finally {
        dashboard?.dispose();
      }
    },
  });
}
