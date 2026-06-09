/**
 * TUI components for the PR reviewer: PR picker, summary walkthrough, and the
 * one-issue-at-a-time navigator. Built with ctx.ui.custom + hand-rolled
 * components to match this pi build (no SelectList dependency).
 */

import type { ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { matchesKey, Text, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { type Issue, type PRListItem, SEVERITY_RANK, type Severity } from "./types.js";

interface Tui {
  requestRender(): void;
}

function wrap(text: string, width: number): string[] {
  const out: string[] = [];
  for (const rawLine of text.split("\n")) {
    if (rawLine.length === 0) {
      out.push("");
      continue;
    }
    let line = "";
    for (const word of rawLine.split(/\s+/)) {
      if (line === "") {
        line = word;
      } else if (visibleWidth(`${line} ${word}`) <= width) {
        line += ` ${word}`;
      } else {
        out.push(line);
        line = word;
      }
      // Hard-break very long words.
      while (visibleWidth(line) > width) {
        out.push(line.slice(0, width));
        line = line.slice(width);
      }
    }
    out.push(line);
  }
  return out;
}

function severityColor(theme: Theme, sev: Severity): string {
  switch (sev) {
    case "critical":
    case "high":
      return "error";
    case "medium":
      return "warning";
    case "low":
      return "muted";
    default:
      return "dim";
  }
}

// ---------------------------------------------------------------------------
// PR picker
// ---------------------------------------------------------------------------

class PRPicker {
  private selected = 0;
  private cachedWidth?: number;
  private cachedLines?: string[];

  constructor(
    private prs: PRListItem[],
    private theme: Theme,
    private tui: Tui,
    private onPick: (n: number | null) => void,
  ) {}

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
      this.onPick(null);
      return;
    }
    if (matchesKey(data, "up") && this.selected > 0) {
      this.selected--;
    } else if (matchesKey(data, "down") && this.selected < this.prs.length - 1) {
      this.selected++;
    } else if (matchesKey(data, "enter")) {
      this.onPick(this.prs[this.selected]?.number ?? null);
      return;
    } else {
      return;
    }
    this.invalidate();
    this.tui.requestRender();
  }

  render(width: number): string[] {
    if (this.cachedLines && this.cachedWidth === width) return this.cachedLines;
    const th = this.theme;
    const lines: string[] = [""];
    lines.push(truncateToWidth(th.fg("accent", " Select a PR to review "), width));
    lines.push("");
    if (this.prs.length === 0) {
      lines.push(truncateToWidth(`  ${th.fg("dim", "No open PRs found.")}`, width));
    }
    this.prs.forEach((pr, i) => {
      const cursor = i === this.selected ? th.fg("accent", "›") : " ";
      const num = th.fg("accent", `#${pr.number}`);
      const draft = pr.isDraft ? th.fg("warning", " [draft]") : "";
      const stats = th.fg("dim", `(${pr.author}, ${pr.changedFiles}f +${pr.additions}/-${pr.deletions})`);
      const titleColor = i === this.selected ? "text" : "muted";
      const title = th.fg(titleColor, pr.title);
      lines.push(truncateToWidth(`${cursor} ${num}${draft} ${title} ${stats}`, width));
    });
    lines.push("");
    lines.push(truncateToWidth(`  ${th.fg("dim", "↑↓ navigate · enter select · esc cancel")}`, width));
    lines.push("");
    this.cachedWidth = width;
    this.cachedLines = lines;
    return lines;
  }

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedLines = undefined;
  }
}

export function pickPR(ctx: ExtensionContext, prs: PRListItem[]): Promise<number | null> {
  return ctx.ui.custom<number | null>((tui, theme, _kb, done) => new PRPicker(prs, theme, tui, done));
}

// ---------------------------------------------------------------------------
// Summary walkthrough
// ---------------------------------------------------------------------------

class SummaryView {
  private scroll = 0;
  private cachedWidth?: number;
  private cachedAll?: string[];

  constructor(
    private title: string,
    private body: string,
    private theme: Theme,
    private tui: Tui,
    private onClose: () => void,
  ) {}

  private allLines(width: number): string[] {
    if (this.cachedAll && this.cachedWidth === width) return this.cachedAll;
    const th = this.theme;
    const lines: string[] = ["", truncateToWidth(th.fg("accent", ` ${this.title} `), width), ""];
    for (const l of wrap(this.body, Math.max(10, width - 2))) {
      lines.push(truncateToWidth(`  ${th.fg("text", l)}`, width));
    }
    this.cachedAll = lines;
    this.cachedWidth = width;
    return lines;
  }

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c") || matchesKey(data, "enter")) {
      this.onClose();
      return;
    }
    if (matchesKey(data, "up")) this.scroll = Math.max(0, this.scroll - 1);
    else if (matchesKey(data, "down")) this.scroll++;
    else return;
    this.tui.requestRender();
  }

  render(width: number): string[] {
    const all = this.allLines(width);
    const th = this.theme;
    const maxScroll = Math.max(0, all.length - 1);
    if (this.scroll > maxScroll) this.scroll = maxScroll;
    const visible = all.slice(this.scroll);
    visible.push(truncateToWidth(`  ${th.fg("dim", "↑↓ scroll · enter/esc continue")}`, width));
    return visible;
  }

  invalidate(): void {
    this.cachedAll = undefined;
    this.cachedWidth = undefined;
  }
}

export function showSummary(ctx: ExtensionContext, title: string, body: string): Promise<void> {
  return ctx.ui.custom<void>((tui, theme, _kb, done) => new SummaryView(title, body, theme, tui, () => done()));
}

// ---------------------------------------------------------------------------
// Issue navigator (one issue at a time, ordered by criticality)
// ---------------------------------------------------------------------------

class IssueNavigator {
  private index = 0;
  private cachedWidth?: number;
  private cachedLines?: string[];

  constructor(
    private issues: Issue[],
    private theme: Theme,
    private tui: Tui,
    private onClose: () => void,
  ) {}

  handleInput(data: string): void {
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c") || matchesKey(data, "q")) {
      this.onClose();
      return;
    }
    if ((matchesKey(data, "right") || matchesKey(data, "enter") || data === "n") && this.index < this.issues.length - 1) {
      this.index++;
    } else if ((matchesKey(data, "left") || data === "p") && this.index > 0) {
      this.index--;
    } else {
      return;
    }
    this.invalidate();
    this.tui.requestRender();
  }

  render(width: number): string[] {
    if (this.cachedLines && this.cachedWidth === width) return this.cachedLines;
    const th = this.theme;
    const issue = this.issues[this.index];
    const lines: string[] = [""];
    lines.push(
      truncateToWidth(
        `${th.fg("accent", ` Review issues `)}${th.fg("dim", `(${this.index + 1}/${this.issues.length})`)}`,
        width,
      ),
    );
    lines.push("");
    if (!issue) {
      lines.push(truncateToWidth(`  ${th.fg("success", "No issues found. ")}`, width));
      lines.push("");
      lines.push(truncateToWidth(`  ${th.fg("dim", "esc to close")}`, width));
      this.cachedLines = lines;
      this.cachedWidth = width;
      return lines;
    }

    const sevC = severityColor(th, issue.severity);
    const badge = th.fg(sevC, `[${issue.severity.toUpperCase()}]`);
    const cat = th.fg("muted", `(${issue.category})`);
    lines.push(truncateToWidth(`  ${badge} ${cat} ${th.fg("text", issue.title)}`, width));
    if (issue.file) {
      const loc = issue.line !== undefined && issue.line !== null ? `${issue.file}:${issue.line}` : issue.file;
      lines.push(truncateToWidth(`  ${th.fg("accent", loc)}`, width));
    }
    if (issue.reporters && issue.reporters.length > 0) {
      lines.push(truncateToWidth(`  ${th.fg("dim", `flagged by: ${issue.reporters.join(", ")}`)}`, width));
    }
    lines.push("");
    lines.push(truncateToWidth(`  ${th.fg("muted", "Why")}`, width));
    for (const l of wrap(issue.rationale, Math.max(10, width - 4))) {
      lines.push(truncateToWidth(`    ${th.fg("text", l)}`, width));
    }
    lines.push("");
    lines.push(truncateToWidth(`  ${th.fg("muted", "Fix")}`, width));
    for (const l of wrap(issue.recommendation, Math.max(10, width - 4))) {
      lines.push(truncateToWidth(`    ${th.fg("text", l)}`, width));
    }
    lines.push("");
    lines.push(truncateToWidth(`  ${th.fg("dim", "← prev · → / enter next · q/esc close")}`, width));
    lines.push("");

    this.cachedLines = lines;
    this.cachedWidth = width;
    return lines;
  }

  invalidate(): void {
    this.cachedLines = undefined;
    this.cachedWidth = undefined;
  }
}

export function navigateIssues(ctx: ExtensionContext, issues: Issue[]): Promise<void> {
  return ctx.ui.custom<void>((tui, theme, _kb, done) => new IssueNavigator(issues, theme, tui, () => done()));
}

/** Build a plain-text report for dumping into the editor. */
export function buildReport(prNumber: number, prTitle: string, tier: string, issues: Issue[]): string {
  const lines: string[] = [`# PR #${prNumber} review — ${prTitle}`, `Tier: ${tier} · ${issues.length} issue(s)`, ""];
  const sorted = [...issues].sort((a, b) => SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity]);
  sorted.forEach((issue, i) => {
    const loc = issue.file ? ` (${issue.file}${issue.line != null ? `:${issue.line}` : ""})` : "";
    lines.push(`## ${i + 1}. [${issue.severity.toUpperCase()}] ${issue.title}${loc}`);
    lines.push(`- category: ${issue.category}`);
    if (issue.reporters?.length) lines.push(`- flagged by: ${issue.reporters.join(", ")}`);
    lines.push(`- why: ${issue.rationale}`);
    lines.push(`- fix: ${issue.recommendation}`);
    lines.push("");
  });
  return lines.join("\n");
}
