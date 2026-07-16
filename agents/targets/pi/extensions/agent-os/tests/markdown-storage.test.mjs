import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { readMarkdownData, readMarkdownThreads, updateMarkdownThread } from "../core/markdown-store.ts";
import { handleCapture } from "../commands/capture.ts";
import { handleNewThread, handleReconcile } from "../commands/thread.ts";
import { handleFocus } from "../commands/focus.ts";

function context(workspace) {
  return {
    workspacePath: workspace,
    storePath: path.join(workspace, "runtime"),
    repoPath: workspace,
    scope: "personal",
    scopeReason: "test",
    mode: "OS",
    writeEnabled: true,
    repoExists: true,
    policy: null,
  };
}

test("discovers canonical OKF Thread documents and preserves their bodies", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-markdown-"));
  const file = path.join(workspace, "threads", "canonical-thread", "README.md");
  await fs.mkdir(path.dirname(file), { recursive: true });
  const body = "# Canonical Thread\n\nHuman notes stay here.\n\n<!-- agentic-os:generated:start -->\nold generated\n<!-- agentic-os:generated:end -->\n";
  await fs.writeFile(file, `---\ntype: Thread\nid: thread:canonical-thread\nslug: canonical-thread\ntitle: Canonical Thread\nkind: initiative\nstage: in-progress\nstatus: active\ncreatedAt: 2026-01-01T00:00:00.000Z\nlinear: {"initiatives":[],"projects":[]}\nkbs: []\nrepos: []\n---\n\n${body}`, "utf8");

  const threads = await readMarkdownThreads(workspace);
  assert.equal(threads[0].slug, "canonical-thread");
  assert.equal(threads[0].kind, "initiative");
  assert.equal(threads[0].stage, "in-progress");
  assert.equal(threads[0].status, "active");
  assert.match((await fs.readFile(file, "utf8")), /Human notes stay here/);
  await updateMarkdownThread(file, { status: "paused" });
  const roundTripped = await readMarkdownThreads(workspace);
  assert.deepEqual(roundTripped[0].linear, { initiatives: [], projects: [] });
  assert.deepEqual(roundTripped[0].kbs, []);
  assert.deepEqual(roundTripped[0].repos, []);
});

test("derives missing Thread fields from the directory, README, and defaults", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-markdown-"));
  const file = path.join(workspace, "threads", "legacy-thread", "README.md");
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, "---\ntype: Thread\n---\n\n# Legacy Thread\n\nNotes\n", "utf8");

  const threads = await readMarkdownThreads(workspace);
  const thread = threads[0];
  assert.equal(thread.id, "thread:legacy-thread");
  assert.equal(thread.slug, "legacy-thread");
  assert.equal(thread.title, "Legacy Thread");
  assert.equal(thread.kind, "project");
  assert.equal(thread.status, "active");
  assert.equal(thread.stage, "unspecified");
  assert.equal(thread.createdAt, (await fs.stat(file)).mtime.toISOString());
});

test("warns on a Thread slug mismatch while using the containing directory", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-markdown-"));
  const file = path.join(workspace, "threads", "directory-slug", "README.md");
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, "---\ntype: Thread\nslug: frontmatter-slug\n---\n\n# Directory Thread\n", "utf8");
  const warnings = [];
  const originalWarn = console.warn;
  console.warn = (...args) => warnings.push(args.join(" "));
  try {
    const [thread] = await readMarkdownThreads(workspace);
    assert.equal(thread.slug, "directory-slug");
  } finally {
    console.warn = originalWarn;
  }
  assert.match(warnings[0], /frontmatter-slug.*directory-slug/);
});

test("new-thread and capture write Markdown records without threads JSONL", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-markdown-"));
  const agentos = context(workspace);
  let active;
  await handleNewThread("A canonical thread --kind initiative", agentos, (_workspace, slug) => { active = slug; });
  assert.equal(active, "a-canonical-thread");
  const threadFile = path.join(workspace, "threads", active, "README.md");
  const threadText = await fs.readFile(threadFile, "utf8");
  assert.match(threadText, /type: Thread/);
  assert.match(threadText, /linear: \{"initiatives":\[\],"projects":\[\]\}/);
  assert.match(threadText, /kbs: \[\]/);
  assert.match(threadText, /repos: \[\]/);
  assert.equal(await fs.stat(path.join(workspace, "runtime", "threads.jsonl")).catch(() => null), null);

  const output = await handleCapture("decision: Keep Markdown authoritative", agentos, () => active);
  assert.match(output, /decision captured/);
  const decisions = await fs.readdir(path.join(workspace, "threads", active, "decisions"));
  assert.equal(decisions.length, 1);
  assert.match(await fs.readFile(path.join(workspace, "threads", active, "decisions", decisions[0]), "utf8"), /Keep Markdown authoritative/);
  assert.deepEqual((await readMarkdownData(workspace)).threads.map((thread) => thread.slug), [active]);
});

test("reconcile only moves matching inbox documents and rejects unknown threads", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-markdown-"));
  const thread = path.join(workspace, "threads", "one", "README.md");
  await fs.mkdir(path.join(workspace, "inbox", "sessions"), { recursive: true });
  await fs.mkdir(path.join(workspace, "inbox", "decisions"), { recursive: true });
  await fs.mkdir(path.dirname(thread), { recursive: true });
  await fs.writeFile(thread, "---\ntype: Thread\nid: thread:one\nslug: one\ntitle: One\nkind: project\nstage: discovery\nstatus: active\ncreatedAt: 2026-01-01T00:00:00.000Z\n---\n\n# One\n", "utf8");
  await fs.writeFile(path.join(workspace, "inbox", "sessions", "match.md"), "---\ntype: Session\nthread: __inbox__\nproject_slug: one\n---\n\n# Match\n", "utf8");
  await fs.writeFile(path.join(workspace, "inbox", "decisions", "unrelated.md"), "---\ntype: Decision\nid: unrelated\nsource: pi\nthread: __inbox__\ncreatedAt: 2026-01-01T00:00:00.000Z\nproject_slug: other\n---\n\n# Unrelated\n", "utf8");

  await handleReconcile("one", context(workspace));
  assert.equal(await fs.stat(path.join(workspace, "threads", "one", "sessions", "match.md")).then(() => true), true);
  assert.equal(await fs.stat(path.join(workspace, "inbox", "decisions", "unrelated.md")).then(() => true), true);
  await assert.rejects(() => handleReconcile("missing", context(workspace)), /thread not found/);
});

test("focus reads Markdown threads and record documents", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-markdown-"));
  const thread = path.join(workspace, "threads", "focused", "README.md");
  await fs.mkdir(path.join(workspace, "threads", "focused", "blockers"), { recursive: true });
  await fs.writeFile(thread, "---\ntype: Thread\nid: thread:focused\nslug: focused\ntitle: Focused\nkind: exploration\nstage: discovery\nstatus: active\ncreatedAt: 2026-01-01T00:00:00.000Z\n---\n\n# Focused\n\nNotes\n", "utf8");
  await fs.writeFile(path.join(workspace, "threads", "focused", "blockers", "one.md"), "---\ntype: Blocker\nid: blocker:one\nstatus: open\ncreatedAt: 2026-01-01T00:00:00.000Z\n---\n\n# Blocker\n\nWaiting on input\n", "utf8");
  const output = await handleFocus("", context(workspace));
  assert.match(output, /Focused/);
  assert.match(output, /Waiting on input/);
});

test("reads legacy Tasks with mtime timestamps and tolerant defaults", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-markdown-"));
  const bundle = path.join(workspace, "threads", "legacy-thread", "tasks", "legacy-package");
  const packagePath = path.join(bundle, "package.md");
  await Promise.all(["input", "runs", "artifacts"].map((directory) => fs.mkdir(path.join(bundle, directory), { recursive: true })));
  await fs.writeFile(packagePath, "---\ntype: Task\nstatus: ready\n---\n\n# Legacy Task\n", "utf8");
  const mtime = new Date("2025-05-06T07:08:09.000Z");
  await fs.utimes(packagePath, mtime, mtime);

  const [task] = (await readMarkdownData(workspace)).tasks;
  assert.equal(task.id, "legacy-package");
  assert.equal(task.title, "Legacy Task");
  assert.equal(task.thread, "legacy-thread");
  assert.equal(task.status, "draft");
  assert.equal(task.createdAt, mtime.toISOString());
});
