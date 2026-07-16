import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { handleTask } from "../commands/task.ts";
import { initializeWorkspace } from "../core/layout.ts";
import { policyFor } from "../core/policy.ts";
import { createTask } from "../core/task.ts";

function context(workspace, mode, thread, taskPath) {
  return {
    workspacePath: workspace,
    storePath: path.join(workspace, "runtime"),
    repoPath: workspace,
    scope: "personal",
    scopeReason: "test",
    mode,
    thread,
    taskPath,
    writeEnabled: true,
    repoExists: true,
    policy: policyFor(workspace, mode, thread, taskPath),
  };
}

function binding(thread, task) {
  return { thread, task: task?.path };
}

test("task run launches an injectable factory and writes a run report", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-2-"));
  await initializeWorkspace(workspace);
  const created = await createTask(workspace, "thread-a", "Ship commands");
  let launched;
  const agentos = context(workspace, "Thread", "thread-a");
  const result = await handleTask("run ship-commands", agentos, binding("thread-a"), () => {}, async (task, reportPath) => {
    launched = { task, reportPath };
  });
  assert.equal(launched.task.status, "running");
  assert.equal(launched.reportPath, path.join(created.path, "runs", `${new Date().toISOString().slice(0, 10)}-ship-commands.md`));
  assert.match(result.output, /Started task ship-commands/);
  assert.match(await fs.readFile(launched.reportPath, "utf8"), /type: RunReport/);
  assert.match(await fs.readFile(created.packagePath, "utf8"), /status: "running"/);
});

test("run-report appends the outcome and moves running to review", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-2-"));
  await initializeWorkspace(workspace);
  const created = await createTask(workspace, "thread-a", "Ship commands");
  const agentos = context(workspace, "Thread", "thread-a");
  await handleTask("run ship-commands", agentos, binding("thread-a"), () => {}, async () => {});
  const result = await handleTask("run-report ship-commands success Tests passed", agentos, binding("thread-a"), () => {});
  const report = await fs.readFile(path.join(created.path, "runs", `${new Date().toISOString().slice(0, 10)}-ship-commands.md`), "utf8");
  assert.match(result.output, /to review/);
  assert.match(report, /outcome: "success"/);
  assert.match(report, /Result: success/);
  assert.match(report, /Note: Tests passed/);
  assert.match(await fs.readFile(created.packagePath, "utf8"), /status: "review"/);
});

test("accept and reject are review-only terminal decisions", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-2-"));
  await initializeWorkspace(workspace);
  const accepted = await createTask(workspace, "thread-a", "Accept me");
  const rejected = await createTask(workspace, "thread-a", "Reject me");
  const agentos = context(workspace, "Thread", "thread-a");
  for (const pkg of [accepted, rejected]) await handleTask(`run ${pkg.id}`, agentos, binding("thread-a"), () => {}, async () => {});
  await handleTask(`run-report ${accepted.id} success`, agentos, binding("thread-a"), () => {});
  await handleTask(`run-report ${rejected.id} failure`, agentos, binding("thread-a"), () => {});
  await handleTask(`accept ${accepted.id}`, agentos, binding("thread-a"), () => {});
  await handleTask(`reject ${rejected.id}`, agentos, binding("thread-a"), () => {});
  assert.match(await fs.readFile(accepted.packagePath, "utf8"), /status: "done"/);
  assert.match(await fs.readFile(rejected.packagePath, "utf8"), /status: "failed"/);
  await assert.rejects(() => handleTask(`accept ${accepted.id}`, agentos, binding("thread-a"), () => {}), /invalid task transition/);
});

test("FactoryOS cannot start, accept, reject, or self-promote a task", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-2-"));
  await initializeWorkspace(workspace);
  const created = await createTask(workspace, "thread-a", "Factory gate");
  const other = await createTask(workspace, "thread-a", "Other package");
  const agentos = context(workspace, "Factory", "thread-a", created.path);
  for (const command of [`run ${created.id}`, `accept ${created.id}`, `reject ${created.id}`, `status ${created.id} done`]) {
    await assert.rejects(() => handleTask(command, agentos, binding("thread-a", created), () => {}), /FactoryOS cannot|cannot write/);
  }
  const threadAgent = context(workspace, "Thread", "thread-a");
  await handleTask(`run ${created.id}`, threadAgent, binding("thread-a"), () => {}, async () => {});
  await handleTask(`run ${other.id}`, threadAgent, binding("thread-a"), () => {}, async () => {});
  await assert.rejects(() => handleTask(`run-report ${other.id} success`, agentos, binding("thread-a", created), () => {}), /FactoryOS task binding is fixed/);
});
