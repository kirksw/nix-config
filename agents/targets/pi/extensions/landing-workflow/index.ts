/**
 * Landing Workflow Extension
 *
 * Opens a full-screen Pi TUI panel on /land and runs a real landing workflow:
 * fetch/rebase, tests, optional Pi session share, commit/rebase, tests again,
 * and optional push.
 *
 * Usage:
 *   /land
 *   /land --message "commit message"
 *   /land --test "nix flake check --no-build"
 *   /land --base main --no-share --no-push
 *   /land --yes
 *
 * Keyboard:
 *   Escape / q  close (cancels the active command if still running)
 *   x           cancel current run
 *   Enter       close after success/failure/cancel
 */

import { spawn, spawnSync, type ChildProcessWithoutNullStreams } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import type { ExtensionAPI, Theme } from "@mariozechner/pi-coding-agent";
import { Key, matchesKey, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

type WorkflowStatus = "running" | "success" | "failed" | "cancelled";
type StepStatus = "pending" | "running" | "done" | "failed" | "skipped" | "cancelled";

type CommandResult = {
  code: number;
  stdout: string;
  stderr: string;
};

type LandingOptions = {
  baseBranch?: string;
  testCommand?: string;
  commitMessage?: string;
  skipShare: boolean;
  skipPush: boolean;
  yes: boolean;
  allowBase: boolean;
  forceWithLease: boolean;
  help: boolean;
};

type DirtyFile = {
  status: string;
  path: string;
  pathspecs: string[];
};

type DirtyChunk = {
  name: string;
  paths: string[];
  pathspecs: string[];
  message: string;
};

type LandingPlan = {
  cwd: string;
  repoRoot: string;
  repoLabel: string;
  branch: string;
  baseBranch: string;
  baseRef: string;
  upstream?: string;
  dirty: boolean;
  initialStatus: string;
  dirtyChunks: DirtyChunk[];
  branchAdvice: string;
  testCommand?: string;
  commitMessage?: string;
  sessionFile?: string;
  sessionLabel: string;
  skipShare: boolean;
  skipPush: boolean;
  forceWithLease: boolean;
};

type StepRunResult = {
  status: "done" | "skipped";
  summary: string;
};

type WorkflowStepDefinition = {
  id: string;
  title: string;
  description: string;
  commandLabel?: string;
  run: (panel: LandingWorkflowPanel) => Promise<StepRunResult>;
};

type WorkflowStepState = Omit<WorkflowStepDefinition, "run"> & {
  status: StepStatus;
  startedAt?: number;
  completedAt?: number;
  summary?: string;
  error?: string;
};

type TuiHandle = {
  requestRender: () => void;
};

const DEFAULT_SHARE_VIEWER_URL = "https://pi.dev/session/";
const OUTPUT_LINE_LIMIT = 240;

function shellQuote(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

function stripAnsi(value: string): string {
  return value.replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, "");
}

function formatDuration(ms: number): string {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function padRight(line: string, width: number): string {
  const padding = Math.max(0, width - visibleWidth(line));
  return line + " ".repeat(padding);
}

function makeProgressBar(width: number, ratio: number, theme: Theme, accent: "accent" | "success" | "error"): string {
  const innerWidth = Math.max(8, width);
  const filled = Math.round(innerWidth * Math.min(1, Math.max(0, ratio)));
  const empty = Math.max(0, innerWidth - filled);
  return theme.fg(accent, "█".repeat(filled)) + theme.fg("borderMuted", "░".repeat(empty));
}

function tokenizeArgs(input: string): string[] {
  const tokens: string[] = [];
  let current = "";
  let quote: '"' | "'" | null = null;
  let escaping = false;

  for (const char of input.trim()) {
    if (escaping) {
      current += char;
      escaping = false;
      continue;
    }
    if (char === "\\" && quote !== "'") {
      escaping = true;
      continue;
    }
    if ((char === '"' || char === "'") && !quote) {
      quote = char;
      continue;
    }
    if (char === quote) {
      quote = null;
      continue;
    }
    if (/\s/.test(char) && !quote) {
      if (current) {
        tokens.push(current);
        current = "";
      }
      continue;
    }
    current += char;
  }

  if (current) tokens.push(current);
  return tokens;
}

function validateNonEmptyOption(name: string, value: string | undefined): void {
  if (value !== undefined && !value.trim()) throw new Error(`${name} requires a non-empty value`);
}

function parseLandingOptions(args: string): LandingOptions {
  const options: LandingOptions = {
    skipShare: false,
    skipPush: false,
    yes: false,
    allowBase: false,
    forceWithLease: true,
    help: false,
  };
  const tokens = tokenizeArgs(args);

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i]!;
    const nextValue = (name: string): string | undefined => {
      const value = tokens[i + 1];
      if (!value || value.startsWith("--")) throw new Error(`${name} requires a value`);
      i += 1;
      return value;
    };

    if (token === "--help" || token === "-h") options.help = true;
    else if (token === "--no-share") options.skipShare = true;
    else if (token === "--no-push") options.skipPush = true;
    else if (token === "--yes" || token === "-y") options.yes = true;
    else if (token === "--allow-base") options.allowBase = true;
    else if (token === "--no-force-with-lease") options.forceWithLease = false;
    else if (token === "--base") options.baseBranch = nextValue("--base");
    else if (token.startsWith("--base=")) options.baseBranch = token.slice("--base=".length);
    else if (token === "--test") options.testCommand = nextValue("--test");
    else if (token.startsWith("--test=")) options.testCommand = token.slice("--test=".length);
    else if (token === "--message" || token === "-m") options.commitMessage = nextValue(token);
    else if (token.startsWith("--message=")) options.commitMessage = token.slice("--message=".length);
    else throw new Error(`Unknown /land option: ${token}`);
  }

  validateNonEmptyOption("--base", options.baseBranch);
  validateNonEmptyOption("--test", options.testCommand);
  validateNonEmptyOption("--message", options.commitMessage);

  return options;
}

function runCapture(command: string, cwd: string): CommandResult {
  const result = spawnSync("bash", ["-lc", command], {
    cwd,
    encoding: "utf8",
    env: process.env,
  });
  return {
    code: result.status ?? (result.error ? 1 : 0),
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? (result.error ? String(result.error) : ""),
  };
}

function requireCapture(command: string, cwd: string, label: string): string {
  const result = runCapture(command, cwd);
  if (result.code !== 0) {
    const details = (result.stderr || result.stdout).trim();
    throw new Error(`${label} failed${details ? `: ${details}` : ""}`);
  }
  return result.stdout.trim();
}


function parseDirtyFiles(status: string): DirtyFile[] {
  return status
    .split("\n")
    .map((line) => line.trimEnd())
    .filter(Boolean)
    .map((line) => {
      const statusCode = line.slice(0, 2).trim() || "??";
      const rawPath = line.slice(3);
      const renameParts = rawPath.split(" -> ");
      const paths = renameParts.length === 2 ? [renameParts[0]!, renameParts[1]!] : [rawPath];
      return { status: statusCode, path: paths[paths.length - 1]!, pathspecs: paths };
    });
}

function chunkNameForPath(filePath: string): string {
  const parts = filePath.split("/").filter(Boolean);
  if (parts.length === 0) return filePath;
  if (["agents", "config", "docs", "hosts", "modules", "packages", "scripts", "secrets"].includes(parts[0]!)) {
    return parts.length > 1 ? `${parts[0]}/${parts[1]}` : parts[0]!;
  }
  return parts[0]!;
}

function messageForChunk(name: string, files: DirtyFile[]): string {
  const hasOnlyDocs = files.every((file) => file.path.startsWith("docs/") || file.path.endsWith(".md"));
  const verb = files.some((file) => file.status.includes("D"))
    ? "remove"
    : files.some((file) => file.status.includes("A") || file.status === "??")
      ? "add"
      : "update";
  return `${hasOnlyDocs ? "document" : verb} ${name.replace(/[._-]+/g, " ")}`;
}

function analyzeDirtyChunks(initialStatus: string): DirtyChunk[] {
  const groups = new Map<string, DirtyFile[]>();
  for (const file of parseDirtyFiles(initialStatus)) {
    const name = chunkNameForPath(file.path);
    groups.set(name, [...(groups.get(name) ?? []), file]);
  }

  return [...groups.entries()].map(([name, files]) => ({
    name,
    paths: files.map((file) => file.path),
    pathspecs: [...new Set(files.flatMap((file) => file.pathspecs))],
    message: messageForChunk(name, files),
  }));
}

function buildBranchAdvice(chunks: DirtyChunk[]): string {
  if (chunks.length === 0) return "clean";
  if (chunks.length === 1) return "one logical chunk; current branch is fine";
  return `multiple chunks detected; keep one branch if they share a goal/task, split only if unrelated (${chunks.map((chunk) => chunk.name).join(", ")})`;
}

function formatDirtyAnalysis(chunks: DirtyChunk[], branchAdvice: string): string[] {
  if (chunks.length === 0) return ["Dirty chunks: none", "Branching: current branch is clean"];
  const lines = ["Dirty chunks:"];
  for (const chunk of chunks) {
    const shown = chunk.paths.slice(0, 4).join(", ");
    const more = chunk.paths.length > 4 ? `, +${chunk.paths.length - 4} more` : "";
    lines.push(`- ${chunk.name}: ${chunk.message} (${shown}${more})`);
  }
  lines.push(`Branching: ${branchAdvice}`);
  return lines;
}

function detectBaseBranch(repoRoot: string): string {
  const originHead = runCapture("git symbolic-ref --quiet --short refs/remotes/origin/HEAD", repoRoot).stdout.trim();
  if (originHead.startsWith("origin/")) return originHead.slice("origin/".length);

  for (const candidate of ["main", "master"]) {
    const exists = runCapture(`git show-ref --verify --quiet refs/remotes/origin/${shellQuote(candidate)}`, repoRoot);
    if (exists.code === 0) return candidate;
  }

  return "main";
}

function detectTestCommand(repoRoot: string, explicit?: string): string | undefined {
  if (explicit?.trim()) return explicit.trim();
  if (process.env.PI_LAND_TEST_COMMAND?.trim()) return process.env.PI_LAND_TEST_COMMAND.trim();

  const commands: string[] = [];
  const structureScript = path.join(repoRoot, "scripts", "check-structure.sh");
  if (fs.existsSync(structureScript)) commands.push("./scripts/check-structure.sh");
  if (fs.existsSync(path.join(repoRoot, "flake.nix"))) commands.push("nix flake check --no-build");
  if (commands.length > 0) return commands.join(" && ");

  const packageJsonPath = path.join(repoRoot, "package.json");
  if (fs.existsSync(packageJsonPath)) {
    try {
      const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8")) as { scripts?: Record<string, string> };
      const testScript = packageJson.scripts?.test;
      if (testScript && !testScript.includes("no test specified")) {
        if (fs.existsSync(path.join(repoRoot, "pnpm-lock.yaml"))) return "pnpm test";
        if (fs.existsSync(path.join(repoRoot, "yarn.lock"))) return "yarn test";
        return "npm test";
      }
    } catch {
      // Ignore malformed package.json during test auto-detection.
    }
  }

  if (fs.existsSync(path.join(repoRoot, "Makefile"))) return "make test";
  return undefined;
}

function buildShareViewerUrl(gistId: string): string {
  const base = process.env.PI_SHARE_VIEWER_URL || DEFAULT_SHARE_VIEWER_URL;
  if (base.includes("{id}")) return base.replace("{id}", encodeURIComponent(gistId));
  return `${base}${base.endsWith("/") ? "" : "/"}${gistId}`;
}

function buildHelpText(): string {
  return [
    "/land runs the live landing workflow.",
    "",
    "Options:",
    "  --message, -m <text>       Override message when there is one dirty chunk",
    "  --test <command>           Override detected test command",
    "  --base <branch>            Base branch to rebase onto (default: origin/HEAD, main)",
    "  --no-share                 Skip Pi session HTML gist sharing",
    "  --no-push                  Stop after second test pass",
    "  --yes, -y                  Skip confirmation prompt",
    "  --allow-base               Allow running from the base branch",
    "  --no-force-with-lease      Use plain git push when upstream exists",
    "",
    "Safety: if the working tree changes after /land snapshots it, the commit step aborts.",
  ].join("\n");
}

function buildLandingPlan(
  cwd: string,
  sessionFile: string | undefined,
  sessionLabel: string,
  options: LandingOptions,
): LandingPlan {
  const repoRoot = requireCapture("git rev-parse --show-toplevel", cwd, "Not inside a git repository");
  const branch = requireCapture("git rev-parse --abbrev-ref HEAD", repoRoot, "Unable to read git branch");
  if (branch === "HEAD") throw new Error("/land does not support detached HEAD");

  const baseBranch = options.baseBranch ?? detectBaseBranch(repoRoot);
  if (!options.allowBase && branch === baseBranch) {
    throw new Error(`Refusing to land directly from base branch '${baseBranch}'. Pass --allow-base to override.`);
  }

  const upstreamResult = runCapture("git rev-parse --abbrev-ref --symbolic-full-name @{u}", repoRoot);
  const initialStatus = runCapture("git status --porcelain", repoRoot).stdout.trim();
  const dirty = initialStatus.length > 0;
  const dirtyChunks = analyzeDirtyChunks(initialStatus);

  return {
    cwd,
    repoRoot,
    repoLabel: path.basename(repoRoot),
    branch,
    baseBranch,
    baseRef: `origin/${baseBranch}`,
    upstream: upstreamResult.code === 0 ? upstreamResult.stdout.trim() : undefined,
    dirty,
    initialStatus,
    dirtyChunks,
    branchAdvice: buildBranchAdvice(dirtyChunks),
    testCommand: detectTestCommand(repoRoot, options.testCommand),
    commitMessage: options.commitMessage?.trim(),
    sessionFile,
    sessionLabel,
    skipShare: options.skipShare,
    skipPush: options.skipPush,
    forceWithLease: options.forceWithLease,
  };
}

function buildConfirmation(plan: LandingPlan): string {
  const lines = [
    `Repository: ${plan.repoRoot}`,
    `Branch: ${plan.branch}`,
    `Base: ${plan.baseRef}`,
    `Working tree: ${plan.dirty ? `${plan.dirtyChunks.length} chunk(s) will be committed first` : "clean"}`,
    ...formatDirtyAnalysis(plan.dirtyChunks, plan.branchAdvice),
    `Commit message: ${plan.dirty ? plan.commitMessage ?? "auto per chunk" : "not needed"}`,
    `Tests: ${plan.testCommand ?? "not detected; test steps will be skipped"}`,
    `Share: ${plan.skipShare ? "skipped" : plan.sessionFile ? "create private gist" : "skipped (no persisted Pi session)"}`,
    `Push: ${plan.skipPush ? "skipped" : plan.upstream ? (plan.forceWithLease ? "git push --force-with-lease" : "git push") : "git push -u origin HEAD"}`,
    "",
    "Continue?",
  ];
  return lines.join("\n");
}

function buildWorkflowSteps(plan: LandingPlan): WorkflowStepDefinition[] {
  const testDescription = plan.testCommand ?? "No test command detected; pass --test or set PI_LAND_TEST_COMMAND.";

  return [
    {
      id: "detect-dirty",
      title: "Detect dirty changes",
      description: "Group local changes, propose commit messages, and flag likely branch splits.",
      run: async (panel) => {
        if (!plan.dirty) return { status: "skipped", summary: "Working tree is clean." };
        panel.appendOutput(formatDirtyAnalysis(plan.dirtyChunks, plan.branchAdvice).join("\n"));
        return { status: "done", summary: `${plan.dirtyChunks.length} dirty chunk(s); ${plan.branchAdvice}.` };
      },
    },
    {
      id: "commit-dirty",
      title: "Commit dirty changes",
      description: "Address existing dirty work first, split by detected logical chunks.",
      commandLabel: plan.dirty ? "git add -A -- <chunk> && git commit -m <proposal>" : undefined,
      run: async (panel) => {
        if (!plan.dirty) return { status: "skipped", summary: "No local changes to commit." };
        const statusCheck = `current_status=$(git status --porcelain); if [ "$current_status" != ${shellQuote(plan.initialStatus)} ]; then echo ${shellQuote("Working tree changed during landing; refusing to commit unexpected files.")} >&2; exit 1; fi`;
        await panel.runShell(statusCheck);
        for (const chunk of plan.dirtyChunks) {
          const message = plan.commitMessage && plan.dirtyChunks.length === 1 ? plan.commitMessage : chunk.message;
          await panel.runShell([
            `git add -A -- ${chunk.pathspecs.map(shellQuote).join(" ")}`,
            `git commit -m ${shellQuote(message)}`,
          ].join("\n"));
        }
        return { status: "done", summary: `Committed ${plan.dirtyChunks.length} chunk(s).` };
      },
    },
    {
      id: "fetch-rebase",
      title: "Fetch and pre-rebase",
      description: `Fetch origin and rebase onto ${plan.baseRef}.`,
      commandLabel: `git fetch --prune origin && git rebase ${plan.baseRef}`,
      run: async (panel) => {
        await panel.runShell([
          "git fetch --prune origin",
          `git rebase ${shellQuote(plan.baseRef)}`,
        ].join("\n"));
        return { status: "done", summary: `Fetched origin and rebased onto ${plan.baseRef}.` };
      },
    },
    {
      id: "tests-first",
      title: "Run tests",
      description: testDescription,
      commandLabel: plan.testCommand,
      run: async (panel) => {
        if (!plan.testCommand) return { status: "skipped", summary: "No test command detected." };
        await panel.runShell(plan.testCommand);
        return { status: "done", summary: "Initial test pass completed." };
      },
    },
    {
      id: "share-session",
      title: "Share Pi session link",
      description: "Export the current Pi session to HTML and upload it as a private GitHub gist.",
      commandLabel: plan.sessionFile ? `pi --export ${path.basename(plan.sessionFile)} && gh gist create` : undefined,
      run: async (panel) => {
        if (plan.skipShare) return { status: "skipped", summary: "Skipped by --no-share." };
        if (!plan.sessionFile) return { status: "skipped", summary: "No persisted Pi session file to share." };

        const tmpFile = path.join(os.tmpdir(), `pi-land-${process.pid}-${Date.now()}.html`);
        try {
          await panel.runShell(`pi --export ${shellQuote(plan.sessionFile)} ${shellQuote(tmpFile)}`);
          await panel.runShell("gh auth status >/dev/null");
          const gist = await panel.runShell(`gh gist create --public=false ${shellQuote(tmpFile)}`);
          const gistUrl = stripAnsi(gist.stdout).match(/https:\/\/gist\.github\.com\/\S+/)?.[0] ?? "";
          const gistId = gistUrl.split("/").filter(Boolean).pop();
          if (!gistUrl || !gistId) throw new Error("Unable to parse gist URL from gh output.");
          const shareUrl = buildShareViewerUrl(gistId);
          panel.setShareUrl(shareUrl, gistUrl);
          panel.appendOutput(`Share URL: ${shareUrl}\nGist: ${gistUrl}`);
          return { status: "done", summary: shareUrl };
        } finally {
          fs.rmSync(tmpFile, { force: true });
        }
      },
    },
    {
      id: "tests-second",
      title: "Run tests again",
      description: testDescription,
      commandLabel: plan.testCommand,
      run: async (panel) => {
        if (!plan.testCommand) return { status: "skipped", summary: "No test command detected." };
        await panel.runShell(plan.testCommand);
        return { status: "done", summary: "Post-rebase test pass completed." };
      },
    },
    {
      id: "clean-tree-check",
      title: "Verify clean tree",
      description: "Refuse to continue if tests or share steps generated uncommitted files.",
      commandLabel: "git status --porcelain",
      run: async (panel) => {
        await panel.runShell(`if [ -n "$(git status --porcelain)" ]; then echo ${shellQuote("Working tree became dirty during landing; refusing to push generated files.")} >&2; git status --porcelain >&2; exit 1; fi`);
        return { status: "done", summary: "Working tree is clean." };
      },
    },
    {
      id: "push",
      title: "Push branch",
      description: "Publish the landed branch state to origin.",
      commandLabel: plan.skipPush
        ? undefined
        : plan.upstream
          ? plan.forceWithLease
            ? "git push --force-with-lease"
            : "git push"
          : "git push -u origin HEAD",
      run: async (panel) => {
        if (plan.skipPush) return { status: "skipped", summary: "Skipped by --no-push." };
        const command = plan.upstream ? (plan.forceWithLease ? "git push --force-with-lease" : "git push") : "git push -u origin HEAD";
        await panel.runShell(command);
        return { status: "done", summary: plan.upstream ? `Pushed ${plan.upstream}.` : "Pushed and set upstream to origin/HEAD." };
      },
    },
  ];
}

class LandingWorkflowPanel {
  private readonly tui: TuiHandle;
  private readonly theme: Theme;
  private readonly onClose: () => void;
  private readonly plan: LandingPlan;
  private readonly definitions: WorkflowStepDefinition[];
  private readonly startedAt = Date.now();

  private steps: WorkflowStepState[];
  private status: WorkflowStatus = "running";
  private finishedAt?: number;
  private currentStepIndex = -1;
  private currentProcess: ChildProcessWithoutNullStreams | null = null;
  private currentCommand?: string;
  private outputLines: string[] = [];
  private partialLine = "";
  private shareUrl?: string;
  private gistUrl?: string;
  private version = 0;
  private cachedWidth = -1;
  private cachedVersion = -1;
  private cachedLines: string[] = [];

  constructor(tui: TuiHandle, theme: Theme, definitions: WorkflowStepDefinition[], plan: LandingPlan, onClose: () => void) {
    this.tui = tui;
    this.theme = theme;
    this.onClose = onClose;
    this.plan = plan;
    this.definitions = definitions;
    this.steps = definitions.map(({ id, title, description, commandLabel }) => ({
      id,
      title,
      description,
      commandLabel,
      status: "pending",
    }));
    this.appendOutput(`Landing ${plan.branch} in ${plan.repoRoot}`);
    void this.run().catch((error) => {
      this.status = "failed";
      this.finishedAt = Date.now();
      this.appendOutput(`Internal landing workflow error: ${error instanceof Error ? error.message : String(error)}`);
      this.bumpVersion();
    });
  }

  private bumpVersion(): void {
    this.version += 1;
    this.cachedVersion = -1;
    this.tui.requestRender();
  }

  private completePartialLine(): void {
    if (this.partialLine) {
      this.outputLines.push(stripAnsi(this.partialLine));
      this.partialLine = "";
    }
  }

  appendOutput(text: string): void {
    const normalized = text.replace(/\r/g, "\n");
    const parts = normalized.split("\n");
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i]!;
      const isLast = i === parts.length - 1;
      if (isLast && !normalized.endsWith("\n")) {
        this.partialLine += part;
      } else {
        this.outputLines.push(stripAnsi(this.partialLine + part));
        this.partialLine = "";
      }
    }
    if (this.outputLines.length > OUTPUT_LINE_LIMIT) {
      this.outputLines = this.outputLines.slice(-OUTPUT_LINE_LIMIT);
    }
    this.bumpVersion();
  }

  setShareUrl(shareUrl: string, gistUrl: string): void {
    this.shareUrl = shareUrl;
    this.gistUrl = gistUrl;
    this.bumpVersion();
  }

  async runShell(command: string): Promise<CommandResult> {
    if (this.status === "cancelled") throw new Error("Workflow cancelled");

    this.currentCommand = command;
    this.appendOutput(`$ ${command}`);

    const proc = spawn("bash", ["-lc", command], {
      cwd: this.plan.repoRoot,
      detached: process.platform !== "win32",
      env: { ...process.env, NO_COLOR: "1", CLICOLOR: "0" },
    });
    this.currentProcess = proc;

    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (chunk: Buffer) => {
      const text = chunk.toString();
      stdout += text;
      this.appendOutput(text);
    });
    proc.stderr.on("data", (chunk: Buffer) => {
      const text = chunk.toString();
      stderr += text;
      this.appendOutput(text);
    });

    const result = await new Promise<CommandResult>((resolve, reject) => {
      proc.on("error", reject);
      proc.on("close", (code) => resolve({ code: code ?? 1, stdout, stderr }));
    });

    this.completePartialLine();
    if (this.currentProcess === proc) this.currentProcess = null;
    this.currentCommand = undefined;

    if (result.code !== 0) {
      const details = (stderr || stdout).trim().split("\n").slice(-6).join("\n");
      throw new Error(`Command exited ${result.code}${details ? `:\n${details}` : ""}`);
    }

    this.bumpVersion();
    return result;
  }

  private async run(): Promise<void> {
    for (let i = 0; i < this.definitions.length; i++) {
      if (this.status === "cancelled") return;

      this.currentStepIndex = i;
      const step = this.steps[i]!;
      step.status = "running";
      step.startedAt = Date.now();
      this.bumpVersion();

      try {
        const result = await this.definitions[i]!.run(this);
        step.status = result.status;
        step.summary = result.summary;
        step.completedAt = Date.now();
        this.appendOutput(`${result.status === "skipped" ? "Skipped" : "Completed"}: ${step.title} — ${result.summary}`);
      } catch (error) {
        if (this.status === "cancelled") {
          step.status = "cancelled";
          step.summary = "Cancelled.";
          step.completedAt = Date.now();
          this.finishedAt = step.completedAt;
          this.bumpVersion();
          return;
        }
        step.status = "failed";
        step.error = error instanceof Error ? error.message : String(error);
        step.completedAt = Date.now();
        this.status = "failed";
        this.finishedAt = step.completedAt;
        this.appendOutput(`Failed: ${step.title}\n${step.error}`);
        this.bumpVersion();
        return;
      }
    }

    this.status = "success";
    this.finishedAt = Date.now();
    this.currentStepIndex = -1;
    this.appendOutput("Landing workflow completed successfully.");
    this.bumpVersion();
  }

  private elapsedMs(): number {
    return Math.max(0, (this.finishedAt ?? Date.now()) - this.startedAt);
  }

  private completedStepCount(): number {
    return this.steps.filter((step) => step.status === "done" || step.status === "skipped").length;
  }

  private progress(): number {
    if (this.steps.length === 0) return 1;
    const terminal = this.steps.filter((step) => ["done", "skipped", "failed", "cancelled"].includes(step.status)).length;
    const runningCredit = this.steps.some((step) => step.status === "running") ? 0.35 : 0;
    return Math.min(1, (terminal + runningCredit) / this.steps.length);
  }

  private cancel(): void {
    if (this.status !== "running") return;
    this.status = "cancelled";
    this.finishedAt = Date.now();
    const current = this.steps[this.currentStepIndex];
    if (current?.status === "running") {
      current.status = "cancelled";
      current.completedAt = this.finishedAt;
      current.summary = "Cancelled by user.";
    }
    const proc = this.currentProcess;
    if (proc) {
      try {
        if (process.platform !== "win32" && proc.pid) process.kill(-proc.pid, "SIGTERM");
        else proc.kill("SIGTERM");
      } catch {
        try {
          proc.kill("SIGTERM");
        } catch {
          // Process already exited.
        }
      }
    }
    this.currentProcess = null;
    this.appendOutput("Landing workflow cancelled.");
    this.bumpVersion();
  }

  private close(): void {
    if (this.status === "running") this.cancel();
    this.onClose();
  }

  handleInput(data: string): void {
    if (matchesKey(data, Key.escape) || data === "q" || data === "Q") {
      this.close();
      return;
    }
    if (data === "x" || data === "X") {
      this.cancel();
      return;
    }
    if (matchesKey(data, Key.enter) && this.status !== "running") {
      this.close();
    }
  }

  render(width: number): string[] {
    if (width === this.cachedWidth && this.cachedVersion === this.version) return this.cachedLines;

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
        : this.status === "failed"
          ? error(bold("FAILED"))
          : this.status === "cancelled"
            ? warning(bold("CANCELLED"))
            : warning(bold("RUNNING"));
    const progressAccent = this.status === "success" ? "success" : this.status === "failed" ? "error" : "accent";
    const currentStep = this.steps[this.currentStepIndex];

    lines.push(padRight(border(` ╭${"─".repeat(contentWidth)}╮`), width));
    lines.push(padRight(boxLine(`${accent("◈")} ${bold(accent("Landing Workflow"))} ${statusLabel}`), width));
    lines.push(
      padRight(
        boxLine(
          `${muted(`repo ${this.plan.repoLabel}`)} ${dim("•")} ${muted(`branch ${this.plan.branch}`)} ${dim("•")} ${muted(`base ${this.plan.baseRef}`)} ${dim("•")} ${muted(`session ${this.plan.sessionLabel}`)}`,
        ),
        width,
      ),
    );
    separator();
    lines.push(padRight(boxLine(`${muted("Elapsed")}: ${bold(formatDuration(this.elapsedMs()))}`), width));
    lines.push(
      padRight(
        boxLine(
          `${muted("Progress")}: ${makeProgressBar(Math.max(8, contentWidth - 28), this.progress(), this.theme, progressAccent)} ${bold(`${Math.round(this.progress() * 100)}%`)}`,
        ),
        width,
      ),
    );
    lines.push(
      padRight(
        boxLine(
          `${muted("Current")}: ${currentStep?.status === "running" ? accent(currentStep.title) : this.status === "success" ? success("complete") : this.status === "failed" ? error("stopped on failure") : this.status === "cancelled" ? warning("cancelled") : muted("pending")}`,
        ),
        width,
      ),
    );
    if (this.currentCommand) lines.push(padRight(boxLine(`${muted("Command")}: ${dim(this.currentCommand.replace(/\n/g, " && "))}`), width));
    if (this.shareUrl) lines.push(padRight(boxLine(`${muted("Share")}: ${success(this.shareUrl)}`), width));
    if (this.gistUrl) lines.push(padRight(boxLine(`${muted("Gist")}: ${dim(this.gistUrl)}`), width));

    separator();
    lines.push(padRight(boxLine(bold(accent("Steps"))), width));
    for (let i = 0; i < this.steps.length; i++) {
      const step = this.steps[i]!;
      const icon =
        step.status === "done"
          ? success("✓")
          : step.status === "running"
            ? warning("●")
            : step.status === "failed"
              ? error("✗")
              : step.status === "skipped"
                ? dim("↷")
                : step.status === "cancelled"
                  ? warning("■")
                  : dim("○");
      const duration = step.startedAt ? formatDuration((step.completedAt ?? Date.now()) - step.startedAt) : "--:--";
      const statusText =
        step.status === "done"
          ? success(duration)
          : step.status === "running"
            ? warning(duration)
            : step.status === "failed"
              ? error(duration)
              : step.status === "skipped"
                ? dim("skipped")
                : step.status === "cancelled"
                  ? warning("cancelled")
                  : dim("pending");
      const prefix = `${icon} ${i + 1}. ${step.title}`;
      const spacing = Math.max(1, contentWidth - visibleWidth(prefix) - visibleWidth(statusText));
      lines.push(padRight(boxLine(`${prefix}${" ".repeat(spacing)}${statusText}`), width));
      const detail = step.error ? error(step.error.split("\n")[0]!) : step.summary ? dim(step.summary) : dim(step.description);
      lines.push(padRight(boxLine(`   ${detail}`), width));
    }

    separator();
    lines.push(padRight(boxLine(bold(accent("Output"))), width));
    const outputTail = [...this.outputLines, this.partialLine ? stripAnsi(this.partialLine) : ""].filter(Boolean).slice(-10);
    if (outputTail.length === 0) {
      lines.push(padRight(boxLine(dim("No output yet.")), width));
    } else {
      for (const line of outputTail) lines.push(padRight(boxLine(dim(line)), width));
    }

    separator();
    const footer =
      this.status === "running"
        ? `${dim("Esc/Q close+cancel")} ${dim("•")} ${dim("X cancel")} ${dim("•")} ${dim(`${this.completedStepCount()}/${this.steps.length} complete`)}`
        : `${dim("Esc/Q/Enter close")} ${dim("•")} ${dim(`${this.completedStepCount()}/${this.steps.length} complete`)}`;
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
    if (this.status === "running") this.cancel();
  }
}

export default function landingWorkflowExtension(pi: ExtensionAPI): void {
  pi.registerCommand("land", {
    description: "Run the live git/test/share/push landing workflow",
    handler: async (args, ctx) => {
      let options: LandingOptions;
      try {
        options = parseLandingOptions(args);
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
        return;
      }

      if (options.help) {
        ctx.ui.notify(buildHelpText(), "info");
        return;
      }

      if (!ctx.hasUI || ctx.mode !== "tui") {
        ctx.ui.notify("/land requires interactive TUI mode", "error");
        return;
      }

      const sessionFile = ctx.sessionManager.getSessionFile();
      const sessionLabel = pi.getSessionName() ?? (sessionFile ? path.basename(sessionFile) : "ephemeral");

      let plan: LandingPlan;
      try {
        plan = buildLandingPlan(ctx.cwd, sessionFile, sessionLabel, options);
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
        return;
      }

      if (!options.yes) {
        const confirmed = await ctx.ui.confirm("Run landing workflow?", buildConfirmation(plan));
        if (!confirmed) {
          ctx.ui.notify("/land cancelled", "info");
          return;
        }
      }

      const steps = buildWorkflowSteps(plan);
      await ctx.ui.custom<void>((tui, theme, _keybindings, done) => {
        return new LandingWorkflowPanel(tui, theme, steps, plan, () => done(undefined));
      });
    },
  });
}
