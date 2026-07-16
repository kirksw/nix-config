import test from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import path from "node:path";
import fs from "node:fs/promises";
import { inferMode } from "../core/mode.ts";
import { createWorkpackage, deleteOpenWorkpackages, listWorkpackages, resolveWorkpackage } from "../core/workpackage.ts";
import { handleWorkpackage } from "../commands/workpackage.ts";
import { WorkpackagePicker } from "../commands/workpackage-picker.ts";
import { appendMessage, unreadMessages, ackMessages, mailboxPath } from "../core/mailbox.ts";
import { runtimeFilePath } from "../core/runtime.ts";
import { migrateLegacyRuntime } from "../core/runtime-migration.ts";
import { addTodo, doneTodo, listTodos } from "../core/todo.ts";

test("infers OS, Thread, and Factory modes", () => {
  assert.equal(inferMode(), "OS");
  assert.equal(inferMode("thread", undefined), "Thread");
  assert.equal(inferMode("thread", "wp.md"), "Factory");
  assert.equal(inferMode(undefined, "wp.md"), "OS");
});

test("resolves workpackage bundles and rejects packages from another thread", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-"));
  const root = path.join(workspace, "threads", "one", "workpackages");
  const bundle = path.join(root, "build");
  await fs.mkdir(bundle, { recursive: true });
  await Promise.all(["input", "runs", "output"].map((name) => fs.mkdir(path.join(bundle, name))));
  await fs.writeFile(path.join(bundle, "package.md"), "---\ntype: Workpackage\nid: build\ntitle: Build\nthread: one\nstatus: draft\ncreatedAt: 2026-01-01T00:00:00Z\n---\n\nThread input\n", "utf8");
  const resolved = await resolveWorkpackage(workspace, "one", "build");
  assert.equal(resolved.path, bundle);
  assert.equal(resolved.packagePath, path.join(bundle, "package.md"));
  await assert.rejects(() => resolveWorkpackage(workspace, "two", bundle));
});

test("lists non-closed workpackages and creates draft spar targets", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-"));
  const root = path.join(workspace, "threads", "one", "workpackages");
  await fs.mkdir(root, { recursive: true });
  const open = path.join(root, "open");
  const closed = path.join(root, "closed");
  await Promise.all([open, closed].map(async (bundle) => {
    await fs.mkdir(bundle, { recursive: true });
    await Promise.all(["input", "runs", "output"].map((name) => fs.mkdir(path.join(bundle, name))));
  }));
  await fs.writeFile(path.join(open, "package.md"), "---\ntype: Workpackage\nid: open\ntitle: Open work\nthread: one\nstatus: draft\ncreatedAt: 2026-01-01T00:00:00Z\n---\n", "utf8");
  await fs.writeFile(path.join(closed, "package.md"), "---\ntype: Workpackage\nid: closed\ntitle: Closed work\nthread: one\nstatus: done\ncreatedAt: 2026-01-01T00:00:00Z\n---\n", "utf8");
  const created = await createWorkpackage(workspace, "one", "Plan a spar");
  const packages = await listWorkpackages(workspace, "one");
  assert.deepEqual(packages.map((pkg) => pkg.id), ["open", "plan-a-spar"]);
  assert.equal(created.status, "draft");
  assert.match(await fs.readFile(created.packagePath, "utf8"), /## Spar/);

  const agentos = {
    workspacePath: workspace,
    storePath: path.join(workspace, "runtime"),
    repoPath: workspace,
    scope: "personal",
    mode: "Thread",
    writeEnabled: true,
    repoExists: true,
    scopeReason: "test",
    policy: null,
  };
  const listed = await handleWorkpackage("", agentos, { thread: "one" }, () => {});
  assert.match(listed.output, /plan-a-spar/);
  assert.match(listed.output, /wp spar <title>/);

  const tk = {
    matchesKey: (data, key) => data === key,
    Key: { up: "up", down: "down", enter: "enter", escape: "escape", backspace: "backspace", slash: "/", ctrl: (key) => `ctrl-${key}`, shift: (key) => `shift-${key}` },
    truncateToWidth: (text) => text,
    visibleWidth: (text) => text.length,
  };
  const theme = { fg: (_color, text) => text, bold: (text) => text };
  const picker = new WorkpackagePicker(packages, undefined, theme, tk);
  let choice;
  picker.onSelect = (selected) => { choice = selected; };
  assert.match(picker.render(100).join("\\n"), /spar \/ create draft/);
  picker.handleInput("G");
  picker.handleInput("enter");
  for (const char of "Discuss scope") picker.handleInput(char);
  picker.handleInput("enter");
  assert.deepEqual(choice, { kind: "create", value: "Discuss scope" });
});

test("deletes all open workpackages only within the selected thread", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-"));
  await createWorkpackage(workspace, "one", "First");
  await createWorkpackage(workspace, "one", "Second");
  await createWorkpackage(workspace, "two", "Keep");
  const deleted = await deleteOpenWorkpackages(workspace, "one");
  assert.deepEqual(deleted.map((pkg) => pkg.id), ["first", "second"]);
  assert.deepEqual(await listWorkpackages(workspace, "one"), []);
  assert.deepEqual((await listWorkpackages(workspace, "two")).map((pkg) => pkg.id), ["keep"]);
});

test("rejects legacy flat workpackages after canonical migration", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-"));
  const root = path.join(workspace, "threads", "one", "workpackages");
  await fs.mkdir(root, { recursive: true });
  await fs.writeFile(path.join(root, "legacy.md"), "---\nid: legacy\n---\n", "utf8");
  await assert.rejects(() => resolveWorkpackage(workspace, "one", "legacy"), /not found/);
});

test("routes mailbox writes to recipient scope and reads/acks active scope", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-"));
  await appendMessage(workspace, { id: "os", createdAt: "now", from: { mode: "Thread", thread: "alpha" }, to: { mode: "OS" }, body: "os" });
  await appendMessage(workspace, { id: "one", createdAt: "now", from: { mode: "OS" }, to: { mode: "Thread", thread: "alpha" }, body: "hello" });
  await appendMessage(workspace, { id: "factory", createdAt: "now", from: { mode: "OS" }, to: { mode: "Factory", thread: "alpha", workpackage: "threads/alpha/workpackages/build/package.md" }, body: "factory" });
  assert.equal(await fs.stat(runtimeFilePath(workspace, "mailbox", { mode: "OS" })).then(() => true), true);
  assert.equal(await fs.stat(mailboxPath(workspace, "Thread", "alpha")).then(() => true), true);
  assert.equal(await fs.stat(mailboxPath(workspace, "Factory", "alpha", "build")).then(() => true), true);
  assert.deepEqual((await unreadMessages(workspace, "Thread", "alpha")).map((m) => m.id), ["one"]);
  assert.deepEqual((await unreadMessages(workspace, "Factory", "alpha", "build/package.md")).map((m) => m.id), ["factory"]);
  assert.equal(await ackMessages(workspace, ["one"], "Thread", "alpha"), 1);
  assert.deepEqual((await unreadMessages(workspace, "Thread", "alpha")).map((m) => m.id), []);
});

test("migrates supported legacy runtime records and reports unsupported stores", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-"));
  const legacy = path.join(workspace, ".lifeos", "db");
  await fs.mkdir(legacy, { recursive: true });
  await fs.writeFile(path.join(legacy, "agent-os-messages.jsonl"), JSON.stringify({ id: "legacy-msg", createdAt: "now", from: { mode: "OS" }, to: { mode: "Factory", thread: "alpha", workpackage: "build/package.md" }, body: "hello" }) + "\n");
  await fs.writeFile(path.join(legacy, "agent-os-events.jsonl"), JSON.stringify({ type: "turn_end", at: "now", thread: "alpha", workpackage: "build" }) + "\n");
  const first = await migrateLegacyRuntime(workspace);
  assert.deepEqual(first, { success: true, removed: true, migratedRecords: 2, unsupported: [] });
  assert.equal(await fs.stat(legacy).catch(() => null), null);
  assert.equal((await unreadMessages(workspace, "Factory", "alpha", "build")).length, 1);
  assert.equal((await fs.readFile(runtimeFilePath(workspace, "events", { mode: "Factory", thread: "alpha", workpackage: "build" }), "utf8")).split("\n").filter(Boolean).length, 1);
  const second = await migrateLegacyRuntime(workspace);
  assert.deepEqual(second, { success: true, removed: true, migratedRecords: 0, unsupported: [] });

  const unsupportedWorkspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-"));
  const unsupportedLegacy = path.join(unsupportedWorkspace, ".lifeos", "db");
  await fs.mkdir(unsupportedLegacy, { recursive: true });
  await fs.writeFile(path.join(unsupportedLegacy, "threads.jsonl"), "{\"id\":\"canonical\"}\n");
  const report = await migrateLegacyRuntime(unsupportedWorkspace);
  assert.equal(report.success, false);
  assert.match(report.unsupported[0], /threads\.jsonl/);
  assert.equal(await fs.stat(unsupportedLegacy).then(() => true), true);
});

test("routes todos without replacing frontmatter or human text", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-"));
  const thread = path.join(workspace, "threads", "alpha");
  await fs.mkdir(thread, { recursive: true });
  await fs.writeFile(path.join(thread, "README.md"), "---\ntitle: Alpha\n---\n\nHuman text\n", "utf8");
  const context = { workspacePath: workspace, mode: "Thread", thread: "alpha" };
  await addTodo(context, "ship it");
  assert.match(await fs.readFile(path.join(thread, "README.md"), "utf8"), /title: Alpha/);
  assert.match(await fs.readFile(path.join(thread, "README.md"), "utf8"), /Human text/);
  assert.match(await listTodos(context), /ship it/);
  await doneTodo(context, "1");
  assert.match(await fs.readFile(path.join(thread, "README.md"), "utf8"), /- \[x\] ship it/);

  await addTodo({ workspacePath: workspace, mode: "OS" }, "triage");
  assert.match(await fs.readFile(path.join(workspace, "inbox", "todos.md"), "utf8"), /- \[ \] triage/);
  const workpackage = path.join(thread, "workpackages", "build.md");
  await fs.mkdir(path.dirname(workpackage), { recursive: true });
  await fs.writeFile(workpackage, "---\nid: build\n---\n\nHuman workpackage\n", "utf8");
  await addTodo({ workspacePath: workspace, mode: "Factory", thread: "alpha", workpackage }, "test");
  assert.match(await fs.readFile(workpackage, "utf8"), /Human workpackage/);
  assert.match(await fs.readFile(workpackage, "utf8"), /- \[ \] test/);
});
