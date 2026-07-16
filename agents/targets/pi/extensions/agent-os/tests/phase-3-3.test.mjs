import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { handleRender } from "../commands/render.ts";
import { handleWorkpackage } from "../commands/workpackage.ts";
import { initializeThread, initializeWorkspace } from "../core/layout.ts";
import { policyFor } from "../core/policy.ts";
import { writeOutcomeDocument } from "../core/markdown-store.ts";
import { createWorkpackage, transitionWorkpackage } from "../core/workpackage.ts";

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

function count(text, marker) {
  return text.split(marker).length - 1;
}

test("workpackage state changes refresh only the owning thread generated block", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-3-"));
  await initializeWorkspace(workspace);
  await initializeThread(workspace, "thread-a");
  const readme = path.join(workspace, "threads", "thread-a", "README.md");
  await fs.writeFile(readme, "---\ntype: Thread\nid: thread:thread-a\nslug: thread-a\ntitle: Thread A\nkind: project\nstatus: active\nstage: delivery\ncreatedAt: 2026-01-01T00:00:00.000Z\n---\n\n# Thread A\n\n<!-- agent-os:generated:start -->\nold generated\n<!-- agent-os:generated:end -->\n\n", "utf8");
  await fs.appendFile(readme, "Human thread notes must stay.\n");
  const created = await createWorkpackage(workspace, "thread-a", "Ship views");
  const active = { thread: "thread-a", workpackage: created.path };
  const agentos = context(workspace, "Thread", "thread-a");

  await handleWorkpackage(`status ${created.id} specced`, agentos, active, () => {});
  let text = await fs.readFile(readme, "utf8");
  assert.match(text, /Human thread notes must stay/);
  assert.match(text, /Active workpackage: ship-views/);
  assert.match(text, /ship-views: specced — Ship views \(last run: none\)/);
  assert.equal(count(text, "<!-- agent-os:generated:start -->"), 1);
  assert.equal(count(text, "<!-- agent-os:generated:end -->"), 1);

  await handleWorkpackage(`run ${created.id}`, agentos, active, () => {}, async () => {});
  await handleWorkpackage(`run-report ${created.id} success Checks passed`, agentos, active, () => {});
  text = await fs.readFile(readme, "utf8");
  assert.match(text, /ship-views: review — Ship views \(last run: success\)/);
  assert.equal(count(text, "<!-- agent-os:generated:start -->"), 1);
  assert.equal(count(text, "<!-- agent-os:generated:end -->"), 1);
});

test("render preserves human text, canonical markers, and all three generated levels", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-3-"));
  await initializeWorkspace(workspace);
  await initializeThread(workspace, "thread-a");
  const threadReadme = path.join(workspace, "threads", "thread-a", "README.md");
  await fs.writeFile(threadReadme, "---\ntype: Thread\nid: thread:thread-a\nslug: thread-a\ntitle: Thread A\nkind: project\nstatus: active\nstage: delivery\ncreatedAt: 2026-01-01T00:00:00.000Z\n---\n\n# Thread A\n\n<!-- agent-os:generated:start -->\nold generated\n<!-- agent-os:generated:end -->\n\n", "utf8");
  await fs.appendFile(threadReadme, "Human thread text.\n");
  await fs.writeFile(path.join(workspace, "FOCUS.md"), "# Human focus\n\nKeep this focus note.\n", "utf8");
  await fs.writeFile(path.join(workspace, "TRACKER.md"), "# Human tracker\n\nKeep this tracker note.\n", "utf8");
  const created = await createWorkpackage(workspace, "thread-a", "Ship views");
  await transitionWorkpackage(workspace, "thread-a", created.id, "specced");
  await writeOutcomeDocument(workspace, {
    id: "outcome-1",
    type: "outcome",
    title: "Views shipped",
    thread: "thread-a",
    goal: "Keep the three views aligned",
    state: "in_progress",
    createdAt: "2026-01-01T00:00:00.000Z",
  });

  await handleRender("", context(workspace), { workpackage: created.path });
  await handleRender("", context(workspace), { workpackage: created.path });
  const files = await Promise.all([
    fs.readFile(threadReadme, "utf8"),
    fs.readFile(path.join(workspace, "FOCUS.md"), "utf8"),
    fs.readFile(path.join(workspace, "TRACKER.md"), "utf8"),
  ]);
  for (const text of files) {
    assert.equal(count(text, "<!-- agent-os:generated:start -->"), 1);
    assert.equal(count(text, "<!-- agent-os:generated:end -->"), 1);
  }
  assert.match(files[0], /Human thread text/);
  assert.match(files[0], /ship-views: specced/);
  assert.match(files[1], /Keep this focus note/);
  assert.match(files[1], /Workpackages: ship-views \(specced\)/);
  assert.match(files[1], /Views shipped \(in_progress\)/);
  assert.match(files[2], /Keep this tracker note/);
  assert.match(files[2], /workpackages: ship-views \(specced\)/);
});
