/**
 * Notes Extension
 *
 * `/note [text]` opens a TUI note capture panel. Notes are saved into the
 * correct notes/wiki plane with OKF frontmatter augmented by a tiny Pi model pass.
 */

import { execFile } from "node:child_process";
import * as fs from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";
import { promisify } from "node:util";
import type { ExtensionAPI, ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { matchesKey, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

type Route = "personal" | "work";

type TuiHandle = {
  requestRender: () => void;
};

type SaveResult = {
  repo: string;
  relativePath: string;
  metadataSource: "pi" | "fallback";
};

type SaveOptions = {
  cwd: string;
  model?: string;
  signal?: AbortSignal;
};

type NoteMeta = {
  title: string;
  summary?: string;
  tags?: string[];
  topics?: string[];
  source_type?: "braindump" | "meeting" | "research" | "source" | "idea";
  status?: "raw" | "needs_ingest" | "processed";
};

const execFileAsync = promisify(execFile);

function defaultRepo(route: Route): string {
  const home = os.homedir();
  if (route === "work") {
    return process.env.PI_NOTES_WORK_REPO ?? path.join(home, "git/github.com/kirksw/lunarOS/main");
  }
  return process.env.PI_NOTES_PERSONAL_REPO ?? path.join(home, "git/github.com/kirksw/lifeOS");
}

function defaultRoute(cwd: string): Route {
  const home = os.homedir();
  const workRoots = [
    path.join(home, "git/github.com/lunarway"),
    path.join(home, "git/github.com/kirksw/lunarOS/main"),
  ];
  return workRoots.some((root) => cwd === root || cwd.startsWith(`${root}${path.sep}`)) ? "work" : "personal";
}

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

function timestampParts(date = new Date()): {
  timestamp: string;
  year: string;
  month: string;
  createdAt: string;
} {
  const year = String(date.getFullYear());
  const month = pad2(date.getMonth() + 1);
  const day = pad2(date.getDate());
  const hours = pad2(date.getHours());
  const minutes = pad2(date.getMinutes());
  const seconds = pad2(date.getSeconds());
  const offsetMinutes = -date.getTimezoneOffset();
  const sign = offsetMinutes >= 0 ? "+" : "-";
  const absOffset = Math.abs(offsetMinutes);
  const offset = `${sign}${pad2(Math.floor(absOffset / 60))}:${pad2(absOffset % 60)}`;
  return {
    timestamp: `${year}${month}${day}-${hours}${minutes}${seconds}`,
    year,
    month,
    createdAt: `${year}-${month}-${day}T${hours}:${minutes}:${seconds}${offset}`,
  };
}

function slugify(text: string): string {
  const slug = text
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+/, "")
    .replace(/-+$/, "")
    .replace(/-+/g, "-")
    .slice(0, 48)
    .replace(/-+$/, "");
  return slug || "note";
}

function firstMeaningfulLine(text: string): string {
  return text
    .split("\n")
    .map((line) => line.trim())
    .find((line) => line.length > 0) ?? "note";
}

function escapeYamlString(value: string): string {
  return JSON.stringify(value);
}


function yamlList(values: string[] | undefined): string {
  const clean = (values ?? [])
    .map((value) => String(value).trim())
    .filter(Boolean)
    .slice(0, 12);
  return `[${clean.map(escapeYamlString).join(", ")}]`;
}

function normalizeList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item).trim()).filter(Boolean);
}

function fallbackMeta(body: string): NoteMeta {
  return {
    title: firstMeaningfulLine(body).slice(0, 100),
    tags: [],
    topics: [],
    source_type: "braindump",
    status: "raw",
  };
}

function normalizeMeta(raw: Partial<NoteMeta>, body: string): NoteMeta {
  const fallback = fallbackMeta(body);
  const sourceType = ["braindump", "meeting", "research", "source", "idea"].includes(String(raw.source_type))
    ? raw.source_type
    : fallback.source_type;
  const status = ["raw", "needs_ingest", "processed"].includes(String(raw.status)) ? raw.status : fallback.status;
  return {
    title: String(raw.title || fallback.title).trim().slice(0, 100),
    summary: raw.summary ? String(raw.summary).trim().slice(0, 280) : undefined,
    tags: normalizeList(raw.tags),
    topics: normalizeList(raw.topics),
    source_type: sourceType,
    status,
  };
}

function extractJson<T>(text: string): T | null {
  const fence = /```(?:json)?\s*([\s\S]*?)```/i.exec(text);
  const candidates: string[] = [];
  if (fence) candidates.push(fence[1]);
  const first = text.indexOf("{");
  const last = text.lastIndexOf("}");
  if (first !== -1 && last > first) candidates.push(text.slice(first, last + 1));
  for (const candidate of candidates) {
    try {
      return JSON.parse(candidate.trim()) as T;
    } catch {
      // try next candidate
    }
  }
  return null;
}

function finalAssistantText(stdout: string): string {
  const messages: string[] = [];
  for (const line of stdout.split("\n")) {
    if (!line.trim()) continue;
    try {
      const event = JSON.parse(line) as {
        type?: string;
        message?: { role?: string; content?: Array<{ type?: string; text?: string }> };
      };
      const msg = event.message;
      if (event.type !== "message_end" || msg?.role !== "assistant") continue;
      const text = (msg.content ?? [])
        .filter((part) => part.type === "text" && part.text?.trim())
        .map((part) => part.text ?? "")
        .join("\n")
        .trim();
      if (text) messages.push(text);
    } catch {
      // ignore non-json output
    }
  }
  return messages.length > 0 ? messages[messages.length - 1] : "";
}

async function writeTempFile(dir: string, name: string, content: string): Promise<string> {
  const file = path.join(dir, name);
  await fs.writeFile(file, content, "utf8");
  return file;
}

async function runPiMetadata(body: string, route: Route, opts: SaveOptions): Promise<Partial<NoteMeta> | null> {
  if (process.env.PI_OFFLINE || process.env.PI_NOTES_SKIP_MODEL) return null;

  let tmpDir: string | undefined;
  try {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "pi-note-"));
    const systemFile = await writeTempFile(
      tmpDir,
      "system.md",
      [
        "You add OKF metadata to raw human notes.",
        "Return ONLY JSON with keys: title, summary, tags, topics, source_type, status.",
        "source_type must be one of: braindump, meeting, research, source, idea.",
        "status should usually be raw unless the note clearly asks to ingest/process something.",
        "Do not rewrite or summarize the note body outside the summary field.",
      ].join("\n"),
    );
    const taskFile = await writeTempFile(
      tmpDir,
      "task.md",
      [`Route: ${route}`, "", "Raw note:", "```", body, "```"].join("\n"),
    );
    const args = [
      "--no-extensions",
      "--mode",
      "json",
      "-p",
      "--no-session",
      "--no-context-files",
      "--no-skills",
      "--no-prompt-templates",
      "--no-tools",
    ];
    if (opts.model) args.push("--model", opts.model);
    args.push("--append-system-prompt", systemFile, `@${taskFile}`);

    const result = (await execFileAsync("pi", args, {
      cwd: opts.cwd,
      timeout: 60_000,
      maxBuffer: 1024 * 1024,
      signal: opts.signal,
    })) as { stdout: string };
    return extractJson<Partial<NoteMeta>>(finalAssistantText(result.stdout));
  } catch {
    return null;
  } finally {
    if (tmpDir) await fs.rm(tmpDir, { recursive: true, force: true });
  }
}

async function augmentMetadata(body: string, route: Route, opts: SaveOptions): Promise<NoteMeta & { metadataSource: "pi" | "fallback" }> {
  const raw = await runPiMetadata(body, route, opts);
  if (!raw) return { ...fallbackMeta(body), metadataSource: "fallback" };
  return { ...normalizeMeta(raw, body), metadataSource: "pi" };
}

async function notesBase(repo: string): Promise<string> {
  const coLocated = path.join(repo, "workspace/wiki");
  try {
    const stat = await fs.stat(coLocated);
    if (stat.isDirectory()) return "workspace/wiki";
  } catch {
    // external notes repos keep raw/ and wiki/ at repo root
  }
  return "";
}

async function ensureNotesRepo(repo: string): Promise<void> {
  const gitDir = path.join(repo, ".git");
  try {
    const stat = await fs.stat(gitDir);
    if (!stat.isDirectory()) throw new Error("not a directory");
  } catch {
    throw new Error(`notes repo not found at ${repo}`);
  }
}

async function git(repo: string, args: string[]): Promise<void> {
  await execFileAsync("git", ["-C", repo, ...args], {
    timeout: 30_000,
    maxBuffer: 1024 * 1024,
  });
}

async function saveNote(route: Route, body: string, opts: SaveOptions): Promise<SaveResult> {
  const trimmed = body.trim();
  if (!trimmed) throw new Error("note body is empty");

  const repo = defaultRepo(route);
  await ensureNotesRepo(repo);

  const { timestamp, year, month, createdAt } = timestampParts();
  const meta = await augmentMetadata(trimmed, route, opts);
  const slug = slugify(meta.title);
  const base = await notesBase(repo);
  const relativePath = path.join(base, "raw", "inbox", year, month, `${timestamp}-${slug}.md`);
  const notePath = path.join(repo, relativePath);

  await fs.mkdir(path.dirname(notePath), { recursive: true });
  await fs.writeFile(
    notePath,
    [
      "---",
      "type: Note",
      `title: ${escapeYamlString(meta.title)}`,
      `created: ${createdAt}`,
      `context: ${route}`,
      "source: pi-note",
      `status: ${meta.status ?? "raw"}`,
      `source_type: ${meta.source_type ?? "braindump"}`,
      `metadata_source: ${meta.metadataSource}`,
      `tags: ${yamlList(meta.tags)}`,
      `topics: ${yamlList(meta.topics)}`,
      ...(meta.summary ? [`summary: ${escapeYamlString(meta.summary)}`] : []),
      "---",
      "",
      trimmed,
      "",
    ].join("\n"),
    "utf8",
  );

  await git(repo, ["add", "--", relativePath]);
  await git(repo, ["commit", "--quiet", "--only", "-m", `add ${route} note ${timestamp}-${slug}`, "--", relativePath]);

  return { repo, relativePath, metadataSource: meta.metadataSource };
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
      while (visibleWidth(line) > width) {
        out.push(line.slice(0, width));
        line = line.slice(width);
      }
    }
    out.push(line);
  }
  return out;
}

function padRight(line: string, width: number): string {
  return line + " ".repeat(Math.max(0, width - visibleWidth(line)));
}

class NotesPanel {
  private route: Route;
  private lines: string[];
  private cursorLine: number;
  private cursorColumn: number;
  private status: "editing" | "saving" | "saved" | "error" = "editing";
  private message = "";
  private cachedWidth = -1;
  private cachedVersion = -1;
  private cachedLines: string[] = [];
  private version = 0;

  constructor(
    initialText: string,
    initialRoute: Route,
    private readonly tui: TuiHandle,
    private readonly theme: Theme,
    private readonly done: () => void,
    private readonly saveOptions: SaveOptions,
  ) {
    this.route = initialRoute;
    this.lines = initialText.length > 0 ? initialText.split("\n") : [""];
    this.cursorLine = this.lines.length - 1;
    this.cursorColumn = this.lines[this.cursorLine].length;
  }

  private body(): string {
    return this.lines.join("\n");
  }

  private bump(): void {
    this.version++;
    this.cachedVersion = -1;
    this.tui.requestRender();
  }

  private setMessage(status: typeof this.status, message: string): void {
    this.status = status;
    this.message = message;
    this.bump();
  }

  private insertText(text: string): void {
    const current = this.lines[this.cursorLine];
    this.lines[this.cursorLine] = current.slice(0, this.cursorColumn) + text + current.slice(this.cursorColumn);
    this.cursorColumn += text.length;
    this.bump();
  }

  private newline(): void {
    const current = this.lines[this.cursorLine];
    const before = current.slice(0, this.cursorColumn);
    const after = current.slice(this.cursorColumn);
    this.lines[this.cursorLine] = before;
    this.lines.splice(this.cursorLine + 1, 0, after);
    this.cursorLine++;
    this.cursorColumn = 0;
    this.bump();
  }

  private backspace(): void {
    if (this.cursorColumn > 0) {
      const current = this.lines[this.cursorLine];
      this.lines[this.cursorLine] = current.slice(0, this.cursorColumn - 1) + current.slice(this.cursorColumn);
      this.cursorColumn--;
      this.bump();
      return;
    }
    if (this.cursorLine > 0) {
      const previousLength = this.lines[this.cursorLine - 1].length;
      this.lines[this.cursorLine - 1] += this.lines[this.cursorLine];
      this.lines.splice(this.cursorLine, 1);
      this.cursorLine--;
      this.cursorColumn = previousLength;
      this.bump();
    }
  }

  private moveLeft(): void {
    if (this.cursorColumn > 0) {
      this.cursorColumn--;
    } else if (this.cursorLine > 0) {
      this.cursorLine--;
      this.cursorColumn = this.lines[this.cursorLine].length;
    }
    this.bump();
  }

  private moveRight(): void {
    if (this.cursorColumn < this.lines[this.cursorLine].length) {
      this.cursorColumn++;
    } else if (this.cursorLine < this.lines.length - 1) {
      this.cursorLine++;
      this.cursorColumn = 0;
    }
    this.bump();
  }

  private moveVertical(delta: number): void {
    this.cursorLine = Math.max(0, Math.min(this.lines.length - 1, this.cursorLine + delta));
    this.cursorColumn = Math.min(this.cursorColumn, this.lines[this.cursorLine].length);
    this.bump();
  }

  private toggleRoute(): void {
    this.route = this.route === "personal" ? "work" : "personal";
    this.setMessage("editing", `route: ${this.route}`);
  }

  private async save(): Promise<void> {
    if (this.status === "saving") return;
    this.setMessage("saving", `augmenting metadata and saving to ${this.route}`);
    try {
      const result = await saveNote(this.route, this.body(), this.saveOptions);
      this.setMessage("saved", `saved ${result.relativePath} (${result.metadataSource} metadata)`);
    } catch (err) {
      this.setMessage("error", (err as Error).message);
    }
  }

  handleInput(data: string): void {
    if (this.status === "saving") return;
    if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
      this.done();
      return;
    }
    if (matchesKey(data, "ctrl+s")) {
      void this.save();
      return;
    }
    if (this.status === "saved" && (matchesKey(data, "enter") || data === "q" || data === "Q")) {
      this.done();
      return;
    }
    if (data === "\t") {
      this.toggleRoute();
      return;
    }
    if (matchesKey(data, "left")) {
      this.moveLeft();
      return;
    }
    if (matchesKey(data, "right")) {
      this.moveRight();
      return;
    }
    if (matchesKey(data, "up")) {
      this.moveVertical(-1);
      return;
    }
    if (matchesKey(data, "down")) {
      this.moveVertical(1);
      return;
    }
    if (matchesKey(data, "backspace") || data === "\x7f") {
      this.backspace();
      return;
    }
    if (matchesKey(data, "enter") || data === "\r" || data === "\n") {
      this.newline();
      return;
    }
    if (data.length === 1 && data >= " " && data !== "\x7f") {
      this.insertText(data);
    }
  }

  render(width: number): string[] {
    if (this.cachedWidth === width && this.cachedVersion === this.version) return this.cachedLines;

    const th = this.theme;
    const contentWidth = Math.max(36, width - 4);
    const border = (s: string) => th.fg("borderMuted", s);
    const accent = (s: string) => th.fg("accent", s);
    const muted = (s: string) => th.fg("muted", s);
    const dim = (s: string) => th.fg("dim", s);
    const error = (s: string) => th.fg("error", s);
    const success = (s: string) => th.fg("success", s);
    const warning = (s: string) => th.fg("warning", s);
    const boxLine = (content: string) => {
      const clipped = truncateToWidth(content, contentWidth);
      return border(" │") + clipped + " ".repeat(Math.max(0, contentWidth - visibleWidth(clipped))) + border("│");
    };

    const routeLabel = this.route === "work" ? warning("work") : accent("personal");
    const statusLabel =
      this.status === "saved"
        ? success("saved")
        : this.status === "error"
          ? error("error")
          : this.status === "saving"
            ? warning("saving")
            : muted("editing");

    const out: string[] = [];
    out.push(padRight(border(` ╭${"─".repeat(contentWidth)}╮`), width));
    out.push(padRight(boxLine(`${accent("Notes")} ${dim("route")} ${routeLabel} ${dim("status")} ${statusLabel}`), width));
    out.push(padRight(boxLine(dim(`repo ${defaultRepo(this.route)}`)), width));
    out.push(padRight(border(` ├${"─".repeat(contentWidth)}┤`), width));

    const bodyLines = this.lines.length === 1 && this.lines[0] === "" ? [dim("Start typing...")] : this.lines;
    const maxBodyLines = 18;
    const start = Math.max(0, Math.min(this.cursorLine - maxBodyLines + 1, bodyLines.length - maxBodyLines));
    const visibleBody = bodyLines.slice(start, start + maxBodyLines);
    for (let i = 0; i < visibleBody.length; i++) {
      const absoluteLine = start + i;
      const prefix = absoluteLine === this.cursorLine ? accent("> ") : dim("  ");
      const line = String(visibleBody[i]);
      const display =
        absoluteLine === this.cursorLine && this.status !== "saved"
          ? `${line.slice(0, this.cursorColumn)}${accent("|")}${line.slice(this.cursorColumn)}`
          : line;
      for (const wrapped of wrap(display, Math.max(10, contentWidth - 2))) {
        out.push(padRight(boxLine(`${prefix}${wrapped}`), width));
      }
    }

    while (out.length < maxBodyLines + 5) {
      out.push(padRight(boxLine(""), width));
    }

    out.push(padRight(border(` ├${"─".repeat(contentWidth)}┤`), width));
    if (this.message) {
      const color = this.status === "error" ? error : this.status === "saved" ? success : muted;
      out.push(padRight(boxLine(color(this.message)), width));
    }
    out.push(
      padRight(
        boxLine(`${dim("Tab route")} ${dim("•")} ${dim("Ctrl-S save")} ${dim("•")} ${dim("Esc cancel")} ${dim("•")} ${dim("Enter newline")}`),
        width,
      ),
    );
    out.push(padRight(border(` ╰${"─".repeat(contentWidth)}╯`), width));

    this.cachedWidth = width;
    this.cachedVersion = this.version;
    this.cachedLines = out;
    return out;
  }
}

function modelString(ctx: ExtensionContext): string | undefined {
  const model = (ctx as ExtensionContext & { model?: { provider?: string; id?: string } }).model;
  if (!model?.id) return undefined;
  return model.provider ? `${model.provider}/${model.id}` : model.id;
}

export default function notesExtension(pi: ExtensionAPI): void {
  pi.registerCommand("note", {
    description: "Capture a personal/work note into the selected notes/wiki plane",
    handler: async (args: string, ctx: ExtensionContext) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("/note requires interactive mode", "error");
        return;
      }

      await ctx.ui.custom<void>((tui, theme, _keybindings, done) => {
        return new NotesPanel(args.trim(), defaultRoute(ctx.cwd), tui, theme, done, {
          cwd: ctx.cwd,
          model: modelString(ctx),
          signal: ctx.signal,
        });
      });
    },
  });
}
