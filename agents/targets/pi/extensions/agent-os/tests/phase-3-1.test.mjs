import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { handleBlocker } from "../commands/blocker.ts";
import { handleOutcome } from "../commands/outcome.ts";
import { handleTask } from "../commands/task.ts";
import { readMarkdownData } from "../core/markdown-store.ts";
import { initializeThread, initializeWorkspace } from "../core/layout.ts";
import { policyFor } from "../core/policy.ts";
import { createTask } from "../core/task.ts";

function context(workspace, mode = "OS", thread) {
  return {
    workspacePath: workspace,
    storePath: path.join(workspace, "runtime"),
    repoPath: workspace,
    scope: "personal",
    scopeReason: "test",
    mode,
    thread,
    writeEnabled: true,
    repoExists: true,
    policy: policyFor(workspace, mode, thread),
  };
}

test("blockers create in the active thread and resolve in place", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-1-"));
  await initializeWorkspace(workspace);
  await initializeThread(workspace, "thread-a");
  await fs.writeFile(path.join(workspace, "threads", "thread-a", "README.md"), "---\ntype: Thread\nid: thread:thread-a\nslug: thread-a\ntitle: Thread A\n---\n", "utf8");
  const agentos = context(workspace);
  const added = await handleBlocker("add Waiting for API", agentos, () => "thread-a");
  const threadDir = path.join(workspace, "threads", "thread-a", "blockers");
  const [createdFile] = await fs.readdir(threadDir);
  assert.match(added, new RegExp(createdFile.replace(".md", "")));
  assert.equal((await readMarkdownData(workspace)).blockers[0].status, "open");

  const id = path.basename(createdFile, ".md");
  await handleBlocker(`resolve ${id}`, agentos, () => "thread-a");
  assert.match(await fs.readFile(path.join(threadDir, createdFile), "utf8"), /status: "resolved"/);
  assert.equal((await readMarkdownData(workspace)).blockers[0].status, "resolved");
});

test("unassigned blockers use the inbox canonical path", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-1-"));
  await initializeWorkspace(workspace);
  const agentos = context(workspace);
  await handleBlocker("add No owner yet", agentos, () => undefined);
  const files = await fs.readdir(path.join(workspace, "inbox", "blockers"));
  assert.equal(files.length, 1);
  const id = path.basename(files[0], ".md");
  await handleBlocker(`resolve ${id}`, agentos, () => undefined);
  assert.equal((await readMarkdownData(workspace)).blockers[0].threadId, undefined);
  assert.equal((await readMarkdownData(workspace)).blockers[0].status, "resolved");
});

test("outcomes follow planned to in_progress to a terminal state", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-1-"));
  await initializeWorkspace(workspace);
  const agentos = context(workspace);
  const added = await handleOutcome("add Ship Phase 3 --goal Deliver command verbs", agentos);
  const id = added.match(/ID: (\S+)/)[1];
  await handleOutcome(`set ${id} in_progress`, agentos);
  await handleOutcome(`set ${id} done`, agentos);
  const outcome = (await readMarkdownData(workspace)).outcomes[0];
  assert.equal(outcome.state, "done");
  assert.ok(outcome.closedAt);
  await assert.rejects(() => handleOutcome(`set ${id} planned`, agentos), /invalid outcome transition/);
});

test("task status command enforces transitions and updates package.md", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-1-"));
  await initializeWorkspace(workspace);
  const created = await createTask(workspace, "thread-a", "Ship commands");
  const agentos = context(workspace, "Thread", "thread-a");
  const before = (await fs.readFile(created.packagePath, "utf8")).match(/updatedAt: "([^"]+)"/)[1];
  await new Promise((resolve) => setTimeout(resolve, 2));
  const result = await handleTask(`status ${created.id} specced`, agentos, { thread: "thread-a" }, () => {});
  assert.match(result.output, /specced/);
  const packageText = await fs.readFile(created.packagePath, "utf8");
  const after = packageText.match(/updatedAt: "([^"]+)"/)[1];
  assert.notEqual(after, before);
  await assert.rejects(() => handleTask(`status ${created.id} done`, agentos, { thread: "thread-a" }, () => {}), /invalid task transition/);
});
