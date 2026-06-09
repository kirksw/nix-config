/**
 * Runner: GitHub (gh) helpers + isolated `pi` subprocess execution.
 *
 * Reviewers run as ephemeral `pi --mode json -p` subprocesses with no tools,
 * fed only the diff. They communicate structured results back as JSON. When a
 * reviewer needs more context it returns `requests`, which the orchestrator
 * fulfills here (reading files / grepping) and feeds back in a follow-up round.
 */

import { type ChildProcess, spawn } from "node:child_process";
import { execFile } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { promisify } from "node:util";
import type { Message } from "@mariozechner/pi-ai";
import type { InfoRequest, PRListItem, PRMeta } from "./types.js";

const execFileAsync = promisify(execFile);

const GH_TIMEOUT_MS = 30_000;
const MAX_DIFF_BYTES = 256 * 1024;
const MAX_REQUEST_FILE_BYTES = 16 * 1024;
const MAX_GREP_MATCHES = 40;

// ---------------------------------------------------------------------------
// gh helpers
// ---------------------------------------------------------------------------

async function gh(args: string[], cwd: string): Promise<string> {
  const { stdout } = await execFileAsync("gh", args, {
    cwd,
    timeout: GH_TIMEOUT_MS,
    maxBuffer: 8 * 1024 * 1024,
  });
  return stdout;
}

export async function listPRs(cwd: string): Promise<PRListItem[]> {
  const raw = await gh(
    [
      "pr",
      "list",
      "--limit",
      "50",
      "--json",
      "number,title,author,headRefName,isDraft,additions,deletions,changedFiles",
    ],
    cwd,
  );
  const parsed = JSON.parse(raw) as Array<{
    number: number;
    title: string;
    author?: { login?: string };
    headRefName: string;
    isDraft: boolean;
    additions: number;
    deletions: number;
    changedFiles: number;
  }>;
  return parsed.map((p) => ({
    number: p.number,
    title: p.title,
    author: p.author?.login ?? "unknown",
    headRefName: p.headRefName,
    isDraft: p.isDraft,
    additions: p.additions,
    deletions: p.deletions,
    changedFiles: p.changedFiles,
  }));
}

export async function getPRMeta(cwd: string, prNumber: number): Promise<PRMeta> {
  const raw = await gh(
    [
      "pr",
      "view",
      String(prNumber),
      "--json",
      "number,title,author,headRefName,baseRefName,isDraft,additions,deletions,changedFiles,body,url",
    ],
    cwd,
  );
  const p = JSON.parse(raw) as {
    number: number;
    title: string;
    author?: { login?: string };
    headRefName: string;
    baseRefName: string;
    isDraft: boolean;
    additions: number;
    deletions: number;
    changedFiles: number;
    body: string;
    url: string;
  };
  return {
    number: p.number,
    title: p.title,
    author: p.author?.login ?? "unknown",
    headRefName: p.headRefName,
    baseRefName: p.baseRefName,
    isDraft: p.isDraft,
    additions: p.additions,
    deletions: p.deletions,
    changedFiles: p.changedFiles,
    body: p.body ?? "",
    url: p.url,
  };
}

export async function getPRDiff(cwd: string, prNumber: number): Promise<string> {
  const diff = await gh(["pr", "diff", String(prNumber)], cwd);
  if (Buffer.byteLength(diff, "utf8") > MAX_DIFF_BYTES) {
    return `${diff.slice(0, MAX_DIFF_BYTES)}\n\n[diff truncated to ${MAX_DIFF_BYTES} bytes]`;
  }
  return diff;
}

// ---------------------------------------------------------------------------
// Info-request fulfillment (orchestrator side)
// ---------------------------------------------------------------------------

function isInsideRepo(repoRoot: string, target: string): boolean {
  const resolved = path.resolve(repoRoot, target);
  const rel = path.relative(repoRoot, resolved);
  return rel !== "" && !rel.startsWith("..") && !path.isAbsolute(rel);
}

async function fulfillRead(cwd: string, req: InfoRequest): Promise<string> {
  if (!req.path || !isInsideRepo(cwd, req.path)) {
    return `read ${req.path ?? "(missing path)"}: rejected (outside repo or invalid)`;
  }
  const abs = path.resolve(cwd, req.path);
  let content: string;
  try {
    content = await fs.promises.readFile(abs, "utf8");
  } catch (err) {
    return `read ${req.path}: error (${(err as Error).message})`;
  }
  let lines = content.split("\n");
  let header = req.path;
  if (req.lines) {
    const m = /^(\d+)\s*-\s*(\d+)$/.exec(req.lines.trim());
    if (m) {
      const start = Math.max(1, Number(m[1]));
      const end = Math.max(start, Number(m[2]));
      lines = lines.slice(start - 1, end).map((l, i) => `${start + i}: ${l}`);
      header = `${req.path}:${start}-${end}`;
    }
  } else {
    lines = lines.map((l, i) => `${i + 1}: ${l}`);
  }
  let body = lines.join("\n");
  if (Buffer.byteLength(body, "utf8") > MAX_REQUEST_FILE_BYTES) {
    body = `${body.slice(0, MAX_REQUEST_FILE_BYTES)}\n[truncated]`;
  }
  return `### read ${header}\n\`\`\`\n${body}\n\`\`\``;
}

async function fulfillGrep(cwd: string, req: InfoRequest): Promise<string> {
  if (!req.pattern) return "grep: rejected (missing pattern)";
  const scope = req.path && isInsideRepo(cwd, req.path) ? req.path : ".";
  try {
    // ripgrep if available; fall back to grep -rn.
    const args = ["-n", "--max-count", String(MAX_GREP_MATCHES), "-e", req.pattern, scope];
    const { stdout } = await execFileAsync("rg", args, { cwd, timeout: 15_000, maxBuffer: 1024 * 1024 });
    const trimmed = stdout.split("\n").slice(0, MAX_GREP_MATCHES).join("\n");
    return `### grep /${req.pattern}/ in ${scope}\n\`\`\`\n${trimmed || "(no matches)"}\n\`\`\``;
  } catch (err) {
    const e = err as { stdout?: string; code?: number };
    if (typeof e.stdout === "string") {
      return `### grep /${req.pattern}/ in ${scope}\n\`\`\`\n${e.stdout || "(no matches)"}\n\`\`\``;
    }
    return `grep /${req.pattern}/: no matches or error`;
  }
}

export async function fulfillRequests(cwd: string, requests: InfoRequest[]): Promise<string> {
  const capped = requests.slice(0, 8);
  const parts: string[] = [];
  for (const req of capped) {
    if (req.type === "read") parts.push(await fulfillRead(cwd, req));
    else if (req.type === "grep") parts.push(await fulfillGrep(cwd, req));
  }
  return parts.join("\n\n");
}

// ---------------------------------------------------------------------------
// pi subprocess runner
// ---------------------------------------------------------------------------

export interface RunPiOptions {
  cwd: string;
  /** "provider/id" to inherit the parent model. */
  model?: string;
  systemPrompt: string;
  task: string;
  /** Comma-allowlist of tools; omitted => --no-tools. */
  tools?: string[];
  signal?: AbortSignal;
}

export interface RunPiResult {
  text: string;
  stopReason?: string;
  exitCode: number;
  stderr: string;
}

function getFinalAssistantText(messages: Message[]): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    const msg = messages[i];
    if (msg.role === "assistant") {
      const text = msg.content
        .filter((part) => part.type === "text" && part.text.trim())
        .map((part) => (part.type === "text" ? part.text : ""))
        .join("\n");
      if (text.trim()) return text;
    }
  }
  return "";
}

async function makeTempDir(): Promise<string> {
  return fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-prreview-"));
}

async function writeTempFile(dir: string, kind: string, name: string, content: string): Promise<string> {
  const safe = name.replace(/[^\w.-]+/g, "_");
  const file = path.join(dir, `${kind}-${safe}.md`);
  await fs.promises.writeFile(file, content, { encoding: "utf8", mode: 0o600 });
  return file;
}

/**
 * Run a single ephemeral pi subprocess and return its final assistant text.
 */
export async function runPi(name: string, opts: RunPiOptions): Promise<RunPiResult> {
  const args = [
    "--mode",
    "json",
    "-p",
    "--no-session",
    "--no-context-files",
    "--no-skills",
    "--no-prompt-templates",
  ];
  if (opts.model) args.push("--model", opts.model);
  if (opts.tools && opts.tools.length > 0) args.push("--tools", opts.tools.join(","));
  else args.push("--no-tools");

  let tmpDir: string | null = null;
  const messages: Message[] = [];
  let stderr = "";
  let stopReason: string | undefined;
  let wasAborted = false;

  try {
    tmpDir = await makeTempDir();
    const systemPromptFile = await writeTempFile(tmpDir, "system", name, opts.systemPrompt);
    const taskFile = await writeTempFile(tmpDir, "task", name, opts.task);
    args.push("--append-system-prompt", systemPromptFile);
    // Pass the PR task via @file so large diffs do not exceed OS argv limits.
    args.push(`@${taskFile}`);

    const exitCode = await new Promise<number>((resolve) => {
      const proc: ChildProcess = spawn("pi", args, {
        cwd: opts.cwd,
        shell: false,
        stdio: ["ignore", "pipe", "pipe"],
        env: { ...process.env, PI_AGENT_NAME: name, PI_PARENT_AGENT: process.env.PI_AGENT_NAME || "" },
      });
      let buffer = "";

      const processLine = (line: string) => {
        if (!line.trim()) return;
        let event: { type?: string; message?: Message };
        try {
          event = JSON.parse(line);
        } catch {
          return;
        }
        if (event.type === "message_end" && event.message) {
          const msg = event.message;
          messages.push(msg);
          if (msg.role === "assistant" && msg.stopReason) stopReason = msg.stopReason;
        }
      };

      proc.stdout?.on("data", (data: Buffer) => {
        buffer += data.toString();
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";
        for (const line of lines) processLine(line);
      });
      proc.stderr?.on("data", (data: Buffer) => {
        stderr += data.toString();
      });
      proc.on("close", (code) => {
        if (buffer.trim()) processLine(buffer);
        resolve(code ?? 0);
      });
      proc.on("error", (err) => {
        stderr += `${err.message}\n`;
        resolve(1);
      });

      if (opts.signal) {
        const kill = () => {
          wasAborted = true;
          proc.kill("SIGTERM");
          setTimeout(() => {
            if (!proc.killed) proc.kill("SIGKILL");
          }, 4000);
        };
        if (opts.signal.aborted) kill();
        else opts.signal.addEventListener("abort", kill, { once: true });
      }
    });

    return {
      text: getFinalAssistantText(messages),
      stopReason: wasAborted ? "aborted" : stopReason,
      exitCode,
      stderr,
    };
  } finally {
    if (tmpDir) {
      try {
        fs.rmSync(tmpDir, { recursive: true, force: true });
      } catch {
        /* ignore */
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Tolerant JSON extraction from model output
// ---------------------------------------------------------------------------

export function extractJson<T>(text: string): T | null {
  if (!text) return null;
  // Prefer a fenced ```json block.
  const fence = /```(?:json)?\s*([\s\S]*?)```/i.exec(text);
  const candidates: string[] = [];
  if (fence) candidates.push(fence[1]);
  // Also try the largest balanced {...} region.
  const firstBrace = text.indexOf("{");
  const lastBrace = text.lastIndexOf("}");
  if (firstBrace !== -1 && lastBrace > firstBrace) {
    candidates.push(text.slice(firstBrace, lastBrace + 1));
  }
  for (const c of candidates) {
    try {
      return JSON.parse(c.trim()) as T;
    } catch {
      /* try next */
    }
  }
  return null;
}
