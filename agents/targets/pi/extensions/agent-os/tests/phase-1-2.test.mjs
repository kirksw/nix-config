import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { migrateGeneratedMarkers, replaceGeneratedBlock } from "../render/markdown.ts";
import { readMarkdownData, readMarkdownThreads, writeMetricDocument, writeOutcomeDocument, writeThreadDocument } from "../core/markdown-store.ts";
import { createTask, transitionTask } from "../core/task.ts";
import { initializeWorkspace, validateWorkspaceLayout } from "../core/layout.ts";
import { promoteArtifactToWiki } from "../core/promotion.ts";

test("generated sections use canonical markers and migrate legacy pairs explicitly", () => {
  const legacy = "notes\n<!-- agentic-os:generated:start -->\nold\n<!-- agentic-os:generated:end -->\n";
  const result = replaceGeneratedBlock(legacy, "new");
  assert.equal(result.changed, false);
  assert.match(result.text, /agentic-os:generated:start/);
  const migrated = migrateGeneratedMarkers(legacy);
  assert.equal(migrated.changed, true);
  assert.match(migrated.text, /agent-os:generated:start/);
  assert.doesNotMatch(migrated.text, /agentic-os:generated/);
});

test("Thread structured fields round-trip without a path frontmatter field", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-1-2-"));
  await initializeWorkspace(workspace);
  const createdAt = "2026-01-01T00:00:00.000Z";
  await writeThreadDocument(workspace, {
    id: "thread:structured", type: "thread", slug: "structured", title: "Structured", kind: "project", status: "active", stage: "new",
    path: "threads/structured", createdAt, updatedAt: createdAt,
    linear: { initiatives: ["init-1"], projects: ["proj-1"] },
    kbs: [{ id: "kb-1", scope: "team", note: "reference" }], repos: ["/repo/example"],
  });
  const thread = (await readMarkdownThreads(workspace))[0];
  assert.deepEqual(thread.linear, { initiatives: ["init-1"], projects: ["proj-1"] });
  assert.deepEqual(thread.kbs, [{ id: "kb-1", scope: "team", note: "reference" }]);
  assert.deepEqual(thread.repos, ["/repo/example"]);
  assert.equal(thread.path, "threads/structured");
  assert.doesNotMatch(await fs.readFile(path.join(workspace, "threads/structured/README.md"), "utf8"), /^path:/m);
});

test("Outcome persists through readMarkdownData", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-1-2-"));
  await initializeWorkspace(workspace);
  await writeOutcomeDocument(workspace, { id: "outcome-1", type: "outcome", title: "Ship", goal: "Ship Phase 1.2", result: "Done", state: "done", createdAt: "2026-01-01T00:00:00.000Z", updatedAt: "2026-01-02T00:00:00.000Z", closedAt: "2026-01-02T00:00:00.000Z" });
  assert.deepEqual((await readMarkdownData(workspace)).outcomes[0], {
    id: "outcome-1", type: "outcome", title: "Ship", goal: "Ship Phase 1.2", result: "Done", state: "done", createdAt: "2026-01-01T00:00:00.000Z", updatedAt: "2026-01-02T00:00:00.000Z", closedAt: "2026-01-02T00:00:00.000Z",
  });
});

test("Metric persistence uses the canonical thread artifact path", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-1-2-"));
  await initializeWorkspace(workspace);
  await writeMetricDocument(workspace, "thread", { id: "metric-1", type: "metric", name: "Coverage", kind: "quantitative", thread: "thread", target: "100", current: "80", createdAt: "2026-01-01T00:00:00.000Z" });
  const data = await readMarkdownData(workspace);
  assert.equal(data.metrics[0].name, "Coverage");
  assert.equal(data.metrics[0].thread, "thread");
  assert.match(data.metrics[0].id, /metric-1/);
  assert.match((await fs.readdir(path.join(workspace, "threads", "thread", "artifacts", "metrics")))[0], /metric-1/);
});

test("Task lifecycle accepts only canonical transitions", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-1-2-"));
  await initializeWorkspace(workspace);
  const created = await createTask(workspace, "thread", "Build");
  for (const status of ["specced", "running", "review", "done"]) await transitionTask(workspace, "thread", created.id, status);
  await assert.rejects(() => transitionTask(workspace, "thread", created.id, "draft"), /invalid task transition/);
  const failed = await createTask(workspace, "thread", "Fail");
  await transitionTask(workspace, "thread", failed.id, "specced");
  await assert.rejects(() => transitionTask(workspace, "thread", failed.id, "review"), /invalid task transition/);
});

test("Factory artifact promotion is explicit and confirmation-gated", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-1-2-"));
  await initializeWorkspace(workspace);
  const output = path.join(workspace, "threads", "thread", "tasks", "build", "artifacts");
  await fs.mkdir(output, { recursive: true });
  await fs.writeFile(path.join(output, "proposal.md"), "proposal", "utf8");
  const proposal = await promoteArtifactToWiki(workspace, "thread", "build", false);
  assert.deepEqual(proposal, { files: ["proposal.md"], promoted: false });
  assert.equal(await fs.stat(path.join(workspace, "wiki", "proposal.md")).catch(() => null), null);
  const promoted = await promoteArtifactToWiki(workspace, "thread", "build", true);
  assert.deepEqual(promoted, { files: ["proposal.md"], promoted: true });
  assert.equal(await fs.readFile(path.join(workspace, "wiki", "proposal.md"), "utf8"), "proposal");
});

test("workspace validation requires exactly the canonical five directories", async () => {
  const workspace = await fs.mkdtemp(path.join(os.tmpdir(), "agent-os-phase-1-2-"));
  await initializeWorkspace(workspace);
  await validateWorkspaceLayout(workspace);
  await fs.mkdir(path.join(workspace, "legacy"));
  await assert.rejects(() => validateWorkspaceLayout(workspace), /non-canonical workspace directories/);
});
