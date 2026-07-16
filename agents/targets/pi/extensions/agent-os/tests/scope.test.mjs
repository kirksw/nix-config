import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { resolveAgentOsContext } from "../core/repo.ts";
import { resolveScope } from "../core/scope.ts";

async function withEnv(values, callback) {
  const previous = new Map();
  for (const [key, value] of Object.entries(values)) {
    previous.set(key, process.env[key]);
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  try {
    return await callback();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

test("maps home-factory and work-factory profiles to Agent OS scopes", async () => {
  await withEnv(
    {
      AGENT_OS_SCOPE: undefined,
      NAX_BASE: "home-factory",
      NAX_PROFILE: undefined,
      PI_CODING_AGENT_DIR: undefined,
    },
    () => assert.deepEqual(resolveScope(), { scope: "personal", reason: "NAX_BASE" }),
  );

  await withEnv(
    {
      AGENT_OS_SCOPE: undefined,
      NAX_BASE: "work-factory",
      NAX_PROFILE: undefined,
      PI_CODING_AGENT_DIR: undefined,
    },
    () => assert.deepEqual(resolveScope(), { scope: "lunar", reason: "NAX_BASE" }),
  );
});

test("resolves a factory profile to its repo workspace and store", async () => {
  const repo = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-repo-"));
  await fs.mkdir(path.join(repo, "workspace"), { recursive: true });

  await withEnv(
    {
      AGENT_OS_SCOPE: undefined,
      AGENT_OS_WORKSPACE_ROOT: undefined,
      AGENT_OS_PERSONAL_REPO: repo,
      NAX_BASE: "home-factory",
      NAX_PROFILE: "home-factory",
      PI_CODING_AGENT_DIR: undefined,
    },
    async () => {
      const context = await resolveAgentOsContext();
      assert.equal(context.scope, "personal");
      assert.equal(context.repoPath, repo);
      assert.equal(context.workspacePath, path.join(repo, "workspace"));
      assert.equal(context.storePath, path.join(repo, "workspace", "runtime"));
      assert.equal(context.writeEnabled, true);
    },
  );
});

test("falls back when a restored workspace binding points to a removed worktree", async () => {
  const repo = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-repo-"));
  await fs.mkdir(path.join(repo, "workspace"), { recursive: true });
  await fs.mkdir(path.join(repo, "main"), { recursive: true });

  await withEnv(
    {
      AGENT_OS_SCOPE: "lunar",
      AGENT_OS_WORKSPACE_ROOT: path.join(repo, "main"),
      AGENT_OS_WORK_REPO: repo,
      NAX_BASE: undefined,
      NAX_PROFILE: undefined,
      PI_CODING_AGENT_DIR: undefined,
    },
    async () => {
      const context = await resolveAgentOsContext();
      assert.equal(context.repoPath, repo);
      assert.equal(context.workspacePath, path.join(repo, "workspace"));
      assert.equal(context.writeEnabled, true);
    },
  );
});
