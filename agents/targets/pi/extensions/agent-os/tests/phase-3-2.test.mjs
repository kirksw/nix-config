import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { handleWorkpackage } from "../commands/workpackage.ts";
import { initializeWorkspace } from "../core/layout.ts";
import { policyFor } from "../core/policy.ts";
import { createWorkpackage } from "../core/workpackage.ts";

function context(workspace, mode, thread, workpackagePath) {
  return {
    workspacePath: workspace,
    storePath: path.join(workspace, "runtime"),
    repoPath: workspace,
    scope: "personal",
    scopeReason: "test",
    mode,
    thread,
    workpackagePath,
    writeEnabled: true,
    repoExists: true,
    policy: policyFor(workspace, mode, thread, workpackagePath),
  };
}

function binding(thread, workpackage) {
  return { thread, workpackage: workpackage?.path };
}

test("wp run launches an injectable factory and writes a run report", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-2-"));
  await initializeWorkspace(workspace);
  const created = await createWorkpackage(workspace, "thread-a", "Ship commands");
  let launched;
  const agentos = context(workspace, "Thread", "thread-a");
  const result = await handleWorkpackage("run ship-commands", agentos, binding("thread-a"), () => {}, async (workpackage, reportPath) => {
    launched = { workpackage, reportPath };
  });
  assert.equal(launched.workpackage.status, "running");
  assert.equal(launched.reportPath, path.join(created.path, "runs", `${new Date().toISOString().slice(0, 10)}-ship-commands.md`));
  assert.match(result.output, /Started workpackage ship-commands/);
  assert.match(await fs.readFile(launched.reportPath, "utf8"), /type: RunReport/);
  assert.match(await fs.readFile(created.packagePath, "utf8"), /status: "running"/);
});

test("run-report appends the outcome and moves running to review", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-2-"));
  await initializeWorkspace(workspace);
  const created = await createWorkpackage(workspace, "thread-a", "Ship commands");
  const agentos = context(workspace, "Thread", "thread-a");
  await handleWorkpackage("run ship-commands", agentos, binding("thread-a"), () => {}, async () => {});
  const result = await handleWorkpackage("run-report ship-commands success Tests passed", agentos, binding("thread-a"), () => {});
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
  const accepted = await createWorkpackage(workspace, "thread-a", "Accept me");
  const rejected = await createWorkpackage(workspace, "thread-a", "Reject me");
  const agentos = context(workspace, "Thread", "thread-a");
  for (const pkg of [accepted, rejected]) await handleWorkpackage(`run ${pkg.id}`, agentos, binding("thread-a"), () => {}, async () => {});
  await handleWorkpackage(`run-report ${accepted.id} success`, agentos, binding("thread-a"), () => {});
  await handleWorkpackage(`run-report ${rejected.id} failure`, agentos, binding("thread-a"), () => {});
  await handleWorkpackage(`accept ${accepted.id}`, agentos, binding("thread-a"), () => {});
  await handleWorkpackage(`reject ${rejected.id}`, agentos, binding("thread-a"), () => {});
  assert.match(await fs.readFile(accepted.packagePath, "utf8"), /status: "done"/);
  assert.match(await fs.readFile(rejected.packagePath, "utf8"), /status: "failed"/);
  await assert.rejects(() => handleWorkpackage(`accept ${accepted.id}`, agentos, binding("thread-a"), () => {}), /invalid workpackage transition/);
});

test("FactoryOS cannot start, accept, reject, or self-promote a workpackage", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-3-2-"));
  await initializeWorkspace(workspace);
  const created = await createWorkpackage(workspace, "thread-a", "Factory gate");
  const other = await createWorkpackage(workspace, "thread-a", "Other package");
  const agentos = context(workspace, "Factory", "thread-a", created.path);
  for (const command of [`run ${created.id}`, `accept ${created.id}`, `reject ${created.id}`, `status ${created.id} done`]) {
    await assert.rejects(() => handleWorkpackage(command, agentos, binding("thread-a", created), () => {}), /FactoryOS cannot|cannot write/);
  }
  const threadAgent = context(workspace, "Thread", "thread-a");
  await handleWorkpackage(`run ${created.id}`, threadAgent, binding("thread-a"), () => {}, async () => {});
  await handleWorkpackage(`run ${other.id}`, threadAgent, binding("thread-a"), () => {}, async () => {});
  await assert.rejects(() => handleWorkpackage(`run-report ${other.id} success`, agentos, binding("thread-a", created), () => {}), /FactoryOS workpackage binding is fixed/);
});
