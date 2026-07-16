import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { policyFor } from "../core/policy.ts";

test("ThreadOS is confined to one thread and ThreadOS-owned package inputs", () => {
  const workspace = "/tmp/life/workspace";
  const thread = path.join(workspace, "threads", "alpha");
  const policy = policyFor(workspace, "Thread", "alpha");

  assert.equal(policy.role, "ThreadOS");
  assert.equal(policy.canRead(path.join(thread, "README.md")), true);
  assert.equal(policy.canRead(path.join(workspace, "threads", "beta", "README.md")), false);
  assert.equal(policy.canWrite(path.join(thread, "package.md")), true);
  assert.equal(policy.canWrite(path.join(thread, "tasks", "build", "package.md")), true);
  assert.equal(policy.canWrite(path.join(thread, "tasks", "build", "input", "plan.md")), true);
  assert.equal(policy.canWrite(path.join(thread, "tasks", "build", "runs", "run.md")), false);
  assert.equal(policy.canWrite(path.join(thread, "tasks", "build", "artifacts", "report.md")), false);
});

test("FactoryOS is confined to one package and FactoryOS-owned outputs", () => {
  const workspace = "/tmp/life/workspace";
  const packageRoot = path.join(workspace, "threads", "alpha", "tasks", "build");
  const policy = policyFor(workspace, "Factory", "alpha", packageRoot);

  assert.equal(policy.role, "FactoryOS");
  assert.equal(policy.canRead(path.join(packageRoot, "package.md")), true);
  assert.equal(policy.canRead(path.join(packageRoot, "input", "plan.md")), true);
  assert.equal(policy.canRead(path.join(workspace, "threads", "alpha", "tasks", "other", "package.md")), false);
  assert.equal(policy.canWrite(path.join(packageRoot, "runs", "2026-run.md")), true);
  assert.equal(policy.canWrite(path.join(packageRoot, "artifacts", "report.md")), true);
  assert.equal(policy.canWrite(path.join(packageRoot, "package.md")), false);
  assert.equal(policy.canWrite(path.join(packageRoot, "input", "plan.md")), false);
});
