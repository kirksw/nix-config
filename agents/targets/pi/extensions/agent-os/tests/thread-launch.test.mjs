import assert from "node:assert/strict";
import test from "node:test";
import { herdrCreateArgs, herdrFactoryRunArgs, herdrRunArgs, rootPaneId } from "../core/herdr-launch.ts";

test("builds a focused Herdr workspace launch", () => {
  assert.deepEqual(
    herdrCreateArgs("/repo/lunarOS", "thread:agentic-os"),
    ["workspace", "create", "--cwd", "/repo/lunarOS", "--label", "thread:agentic-os", "--focus"],
  );
  assert.deepEqual(
    herdrRunArgs("w1:p2", "/repo/lunarOS", "agentic-os"),
    ["pane", "run", "w1:p2", "agent-os launch --thread 'agentic-os' --project '/repo/lunarOS'"],
  );
  assert.deepEqual(
    herdrFactoryRunArgs("w1:p3", "/repo/lunarOS", "agentic-os", "build"),
    ["pane", "run", "w1:p3", "agent-os launch --thread 'agentic-os' --workpackage 'build' --project '/repo/lunarOS'"],
  );
});

test("rejects Herdr responses without a root pane", () => {
  assert.throws(() => rootPaneId(JSON.stringify({ result: { workspace: {} } })), /no root pane/);
  assert.equal(rootPaneId(JSON.stringify({ result: { root_pane: { pane_id: "w1:p2" } } })), "w1:p2");
});
