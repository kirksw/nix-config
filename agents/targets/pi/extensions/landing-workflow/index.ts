/**
 * Landing Workflow Extension
 *
 * Opens a full-screen Pi TUI panel on /land that simulates a landing workflow.
 *
 * Usage:
 *   /land
 *   /land fast
 *   /land slow
 *
 * Keyboard:
 *   Escape / q  close
 *   r           restart
 *   x           cancel current run
 *   Enter       restart after success/cancel
 */

import path from "node:path";
import type { ExtensionAPI, Theme } from "@mariozechner/pi-coding-agent";
import { Key, matchesKey, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

type WorkflowStatus = "idle" | "running" | "success" | "cancelled";
type StepStatus = "pending" | "running" | "done";
type SpeedPreset = "fast" | "normal" | "slow";

type WorkflowStepDefinition = {
  id: string;
  title: string;
  description: string;
  durationMs: number;
};

type WorkflowStepState = WorkflowStepDefinition & {
  status: StepStatus;
  startedAt?: number;
  completedAt?: number;
};

type TuiHandle = {
  requestRender: () => void;
};

const BASE_STEPS: WorkflowStepDefinition[] = [
  {
    id: "fetch-rebase",
    title: "Fetch and rebase",
    description: "Refreshing local branch state before landing starts.",
    durationMs: 1800,
  },
  {
    id: "tests-first",
    title: "Run tests",
    description: "Running the first safety pass before sharing or committing.",
    durationMs: 2600,
  },
  {
    id: "share-session",
    title: "Share Pi session link",
    description: "Packaging session context into a handoff-ready share step.",
    durationMs: 1400,
  },
  {
    id: "commit-rebase",
    title: "Commit and rebase",
    description: "Preparing the branch for a clean landing on top of latest main.",
    durationMs: 1800,
  },
  {
    id: "tests-second",
    title: "Run tests again",
    description: "Verifying the rebased branch is still clean after commit work.",
    durationMs: 2400,
  },
  {
    id: "push",
    title: "Push again",
    description: "Publishing the final branch state so the landing is ready.",
    durationMs: 1600,
  },
];

function clamp(value: number, min = 0, max = 1): number {
  return Math.min(max, Math.max(min, value));
}

function formatDuration(ms: number): string {
  const totalTenths = Math.max(0, Math.floor(ms / 100));
  const minutes = Math.floor(totalTenths / 600);
  const seconds = Math.floor((totalTenths % 600) / 10);
  const tenths = totalTenths % 10;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}.${tenths}`;
}

function padRight(line: string, width: number): string {
  const padding = Math.max(0, width - visibleWidth(line));
  return line + " ".repeat(padding);
}

function makeProgressBar(width: number, ratio: number, theme: Theme, accent: "accent" | "success"): string {
  const innerWidth = Math.max(10, width);
  const filled = Math.round(innerWidth * clamp(ratio));
  const empty = Math.max(0, innerWidth - filled);
  const completeChar = accent === "success" ? "█" : "■";
  return theme.fg(accent, completeChar.repeat(filled)) + theme.fg("borderMuted", "░".repeat(empty));
}

function scaleSteps(preset: SpeedPreset): WorkflowStepDefinition[] {
  const multiplier = preset === "fast" ? 0.7 : preset === "slow" ? 1.5 : 1;
  return BASE_STEPS.map((step) => ({
    ...step,
    durationMs: Math.max(500, Math.round(step.durationMs * multiplier)),
  }));
}

function parseSpeedPreset(args: string): SpeedPreset {
  const normalized = args.trim().toLowerCase();
  if (normalized === "fast") return "fast";
  if (normalized === "slow") return "slow";
  return "normal";
}

class LandingWorkflowPanel {
  private readonly tui: TuiHandle;
  private readonly theme: Theme;
  private readonly onClose: () => void;
  private readonly repoLabel: string;
  private readonly sessionLabel: string;
  private readonly preset: SpeedPreset;

  private steps: WorkflowStepState[];
  private status: WorkflowStatus = "idle";
  private startedAt?: number;
  private finishedAt?: number;
  private currentStepIndex = -1;
  private interval: ReturnType<typeof setInterval> | null = null;
  private version = 0;
  private cachedWidth = -1;
  private cachedVersion = -1;
  private cachedLines: string[] = [];

  constructor(
    tui: TuiHandle,
    theme: Theme,
    steps: WorkflowStepDefinition[],
    options: {
      repoLabel: string;
      sessionLabel: string;
      preset: SpeedPreset;
      onClose: () => void;
    },
  ) {
    this.tui = tui;
    this.theme = theme;
    this.onClose = options.onClose;
    this.repoLabel = options.repoLabel;
    this.sessionLabel = options.sessionLabel;
    this.preset = options.preset;
    this.steps = this.buildInitialSteps(steps);
    this.restart();
  }

  private buildInitialSteps(steps: WorkflowStepDefinition[]): WorkflowStepState[] {
    return steps.map((step) => ({
      ...step,
      status: "pending",
    }));
  }

  private bumpVersion(): void {
    this.version += 1;
    this.cachedVersion = -1;
  }

  private startTimer(): void {
    this.stopTimer();
    this.interval = setInterval(() => {
      this.tick();
    }, 100);
  }

  private stopTimer(): void {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
  }

  private tick(): void {
    if (this.status !== "running") return;
    if (this.currentStepIndex < 0 || this.currentStepIndex >= this.steps.length) return;

    const step = this.steps[this.currentStepIndex];
    if (!step.startedAt) return;

    const now = Date.now();
    const elapsed = now - step.startedAt;
    if (elapsed >= step.durationMs) {
      const completedAt = step.startedAt + step.durationMs;
      step.status = "done";
      step.completedAt = completedAt;

      this.currentStepIndex += 1;
      if (this.currentStepIndex >= this.steps.length) {
        this.status = "success";
        this.finishedAt = completedAt;
        this.stopTimer();
      } else {
        const nextStep = this.steps[this.currentStepIndex];
        nextStep.status = "running";
        nextStep.startedAt = completedAt;
      }
    }

    this.bumpVersion();
    this.tui.requestRender();
  }

  private totalDurationMs(): number {
    return this.steps.reduce((sum, step) => sum + step.durationMs, 0);
  }

  private elapsedMs(): number {
    if (!this.startedAt) return 0;
    const endTime = this.finishedAt ?? Date.now();
    return Math.max(0, endTime - this.startedAt);
  }

  private currentStep(): WorkflowStepState | undefined {
    if (this.currentStepIndex < 0 || this.currentStepIndex >= this.steps.length) return undefined;
    return this.steps[this.currentStepIndex];
  }

  private completedStepCount(): number {
    return this.steps.filter((step) => step.status === "done").length;
  }

  private overallProgress(): number {
    const total = this.totalDurationMs();
    if (total === 0) return 1;

    const completed = this.steps.reduce((sum, step) => {
      if (step.status === "done") return sum + step.durationMs;
      if (step.status === "running" && step.startedAt) {
        return sum + Math.min(step.durationMs, Date.now() - step.startedAt);
      }
      return sum;
    }, 0);

    return clamp(completed / total);
  }

  private stepProgress(step: WorkflowStepState): number {
    if (step.status === "done") return 1;
    if (step.status !== "running" || !step.startedAt) return 0;
    return clamp((Date.now() - step.startedAt) / step.durationMs);
  }

  private stepElapsed(step: WorkflowStepState): number {
    if (step.status === "done" && step.startedAt && step.completedAt) {
      return step.completedAt - step.startedAt;
    }
    if (step.status === "running" && step.startedAt) {
      return Math.min(step.durationMs, Date.now() - step.startedAt);
    }
    return 0;
  }

  private restart(): void {
    this.stopTimer();
    this.steps = this.buildInitialSteps(
      this.steps.map(({ id, title, description, durationMs }) => ({ id, title, description, durationMs })),
    );
    this.status = "running";
    this.startedAt = Date.now();
    this.finishedAt = undefined;
    this.currentStepIndex = 0;
    this.steps[0].status = "running";
    this.steps[0].startedAt = this.startedAt;
    this.startTimer();
    this.bumpVersion();
    this.tui.requestRender();
  }

  private cancel(): void {
    if (this.status !== "running") return;

    this.status = "cancelled";
    this.finishedAt = Date.now();

    const current = this.currentStep();
    if (current && current.status === "running") {
      current.status = "pending";
      current.startedAt = undefined;
    }

    this.currentStepIndex = -1;
    this.stopTimer();
    this.bumpVersion();
    this.tui.requestRender();
  }

  private close(): void {
    this.stopTimer();
    this.onClose();
  }

  handleInput(data: string): void {
    if (matchesKey(data, Key.escape) || data === "q" || data === "Q") {
      this.close();
      return;
    }

    if (data === "r" || data === "R") {
      this.restart();
      return;
    }

    if (data === "x" || data === "X") {
      this.cancel();
      return;
    }

    if (matchesKey(data, Key.enter) && this.status !== "running") {
      this.restart();
    }
  }

  render(width: number): string[] {
    if (width === this.cachedWidth && this.cachedVersion === this.version) {
      return this.cachedLines;
    }

    const lines: string[] = [];
    const contentWidth = Math.max(40, width - 4);
    const border = (s: string) => this.theme.fg("borderMuted", s);
    const accent = (s: string) => this.theme.fg("accent", s);
    const muted = (s: string) => this.theme.fg("muted", s);
    const dim = (s: string) => this.theme.fg("dim", s);
    const success = (s: string) => this.theme.fg("success", s);
    const warning = (s: string) => this.theme.fg("warning", s);
    const error = (s: string) => this.theme.fg("error", s);
    const bold = (s: string) => this.theme.bold(s);
    const boxLine = (content: string) => {
      const clipped = truncateToWidth(content, contentWidth);
      const padding = Math.max(0, contentWidth - visibleWidth(clipped));
      return border(" │") + clipped + " ".repeat(padding) + border("│");
    };
    const separator = () => lines.push(padRight(border(` ├${"─".repeat(contentWidth)}┤`), width));

    const statusLabel =
      this.status === "success"
        ? success(bold("SUCCESS"))
        : this.status === "cancelled"
          ? error(bold("CANCELLED"))
          : warning(bold("RUNNING"));
    const totalSteps = this.steps.length;
    const completedSteps = this.completedStepCount();
    const overallProgress = this.overallProgress();
    const currentStep = this.currentStep();
    const currentStepLabel =
      this.status === "success"
        ? success("All landing steps completed")
        : this.status === "cancelled"
          ? error("Workflow cancelled before landing completed")
          : currentStep
            ? accent(`${this.currentStepIndex + 1}/${totalSteps} · ${currentStep.title}`)
            : muted("Waiting to start");

    const headerTitle = `${accent("◈")} ${bold(accent("Landing Workflow"))}`;
    const headerContext = `${muted(`repo ${this.repoLabel}`)} ${dim("•")} ${muted(`session ${this.sessionLabel}`)} ${dim("•")} ${muted(`preset ${this.preset}`)}`;

    lines.push(padRight(border(` ╭${"─".repeat(contentWidth)}╮`), width));
    lines.push(padRight(boxLine(headerTitle), width));
    lines.push(padRight(boxLine(headerContext), width));
    separator();

    lines.push(padRight(boxLine(`${muted("Status")}: ${statusLabel}`), width));
    lines.push(
      padRight(
        boxLine(
          `${muted("Elapsed")}: ${bold(formatDuration(this.elapsedMs()))} ${dim(`/ ${formatDuration(this.totalDurationMs())}`)}`,
        ),
        width,
      ),
    );
    lines.push(
      padRight(
        boxLine(
          `${muted("Progress")}: ${makeProgressBar(Math.max(10, contentWidth - 26), overallProgress, this.theme, this.status === "success" ? "success" : "accent")} ${bold(`${Math.round(overallProgress * 100)}%`)}`,
        ),
        width,
      ),
    );
    lines.push(padRight(boxLine(`${muted("Current step")}: ${currentStepLabel}`), width));

    if (currentStep && this.status === "running") {
      lines.push(padRight(boxLine(`${dim(currentStep.description)}`), width));
      lines.push(
        padRight(
          boxLine(
            `${muted("Step progress")}: ${makeProgressBar(Math.max(10, contentWidth - 30), this.stepProgress(currentStep), this.theme, "accent")} ${formatDuration(this.stepElapsed(currentStep))} ${dim(`/ ${formatDuration(currentStep.durationMs)}`)}`,
          ),
          width,
        ),
      );
    } else if (this.status === "success") {
      lines.push(padRight(boxLine(success("Landing complete — branch, tests, and share flow all cleared.")), width));
    } else if (this.status === "cancelled") {
      lines.push(padRight(boxLine(warning("Press Enter or R to restart the workflow demo.")), width));
    }

    separator();
    lines.push(padRight(boxLine(bold(accent("Workflow steps"))), width));

    for (let i = 0; i < this.steps.length; i++) {
      const step = this.steps[i];
      const icon =
        step.status === "done"
          ? success("✓")
          : step.status === "running"
            ? warning("●")
            : dim("○");
      const durationLabel =
        step.status === "done"
          ? success(formatDuration(this.stepElapsed(step)))
          : step.status === "running"
            ? warning(`${formatDuration(this.stepElapsed(step))} / ${formatDuration(step.durationMs)}`)
            : dim(`est ${formatDuration(step.durationMs)}`);
      const prefix = `${icon} ${i + 1}. ${step.title}`;
      const spacing = Math.max(1, contentWidth - visibleWidth(prefix) - visibleWidth(durationLabel));
      lines.push(padRight(boxLine(`${prefix}${" ".repeat(spacing)}${durationLabel}`), width));
      lines.push(padRight(boxLine(`   ${dim(step.description)}`), width));
    }

    separator();
    const footer = `${dim("Esc/Q close")} ${dim("•")} ${dim("R restart")} ${dim("•")} ${dim("X cancel")} ${dim("•")} ${dim(`${completedSteps}/${totalSteps} complete`)}`;
    lines.push(padRight(boxLine(footer), width));
    lines.push(padRight(border(` ╰${"─".repeat(contentWidth)}╯`), width));

    this.cachedWidth = width;
    this.cachedVersion = this.version;
    this.cachedLines = lines;
    return lines;
  }

  invalidate(): void {
    this.cachedWidth = -1;
    this.cachedVersion = -1;
  }

  dispose(): void {
    this.stopTimer();
  }
}

export default function landingWorkflowExtension(pi: ExtensionAPI): void {
  pi.registerCommand("land", {
    description: "Open the full-screen Landing Workflow panel",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("/land requires interactive mode", "error");
        return;
      }

      const preset = parseSpeedPreset(args);
      const steps = scaleSteps(preset);
      const repoLabel = path.basename(ctx.cwd);
      const sessionFile = ctx.sessionManager.getSessionFile();
      const sessionLabel = pi.getSessionName() ?? (sessionFile ? path.basename(sessionFile) : "ephemeral");

      await ctx.ui.custom<void>((tui, theme, _keybindings, done) => {
        return new LandingWorkflowPanel(tui, theme, steps, {
          repoLabel,
          sessionLabel,
          preset,
          onClose: () => done(undefined),
        });
      });
    },
  });
}
