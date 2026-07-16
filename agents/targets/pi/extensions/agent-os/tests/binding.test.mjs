import test from "node:test";
import assert from "node:assert/strict";
import { activeThreadFor, bindRestoredThread, restoreBinding, shouldStartThreadSession } from "../core/binding.ts";

test("opens a new thread session from OS repositories only", () => {
  assert.equal(shouldStartThreadSession("/Users/kisw/git/github.com/kirksw/lifeOS"), true);
  assert.equal(shouldStartThreadSession("/Users/kisw/git/github.com/kirksw/lunarOS"), true);
  assert.equal(shouldStartThreadSession("/Users/kisw/git/github.com/kirksw/otherOS"), true);
  assert.equal(shouldStartThreadSession("/Users/kisw/git/github.com/kirksw/nix-config"), false);
});

test("restores the newest persisted binding and normalizes workspace paths", async () => {
  const env = {};
  const binding = restoreBinding([
    { type: "custom", customType: "agent-os-binding", data: {
      version: 1, thread: "old", project: "/old", workspace: "/old-life/workspace",
      updatedAt: "2026-01-01T00:00:00Z",
    } },
    { type: "custom", customType: "agent-os-binding", data: {
      version: 1, thread: "new", workpackage: "threads/new/workpackages/build.md", project: "/project", workspace: "/lifeOS/workspace",
      scope: "personal", updatedAt: "2026-01-02T00:00:00Z",
    } },
  ], env);

  assert.equal(binding.thread, "new");
  assert.equal(env.AGENT_OS_THREAD_ID, "new");
  assert.equal(env.AGENT_OS_PROJECT_ROOT, "/project");
  assert.equal(env.AGENT_OS_WORKPACKAGE, "threads/new/workpackages/build.md");
  assert.equal(env.AGENT_OS_WORKSPACE_ROOT, "/lifeOS");
  assert.equal(env.AGENT_OS_SCOPE, "personal");

  const activeThreads = new Map();
  bindRestoredThread(binding, activeThreads, "/lifeOS/workspace");
  assert.equal(activeThreads.get("/lifeOS/workspace"), "new");
});

test("resolves restored bindings for status and capture lookups", async () => {
  const activeThreads = new Map([["/lifeOS/workspace", "restored-thread"]]);
  assert.equal(activeThreadFor("/lifeOS/workspace", activeThreads, {}), "restored-thread");
  assert.equal(activeThreadFor("/lifeOS/workspace", activeThreads, {
    AGENT_OS_THREAD_ID: "launcher-thread",
  }), "launcher-thread");
  assert.equal(activeThreadFor(null, activeThreads, {}), undefined);
});

test("does not overwrite an explicit launcher binding", async () => {
  const env = { AGENT_OS_THREAD_ID: "launcher-thread" };
  const binding = restoreBinding([
    { type: "custom", customType: "agent-os-binding", data: {
      version: 1, thread: "persisted", project: "/project", updatedAt: "2026-01-01T00:00:00Z",
    } },
  ], env);

  assert.equal(binding, undefined);
  assert.equal(env.AGENT_OS_THREAD_ID, "launcher-thread");
});
