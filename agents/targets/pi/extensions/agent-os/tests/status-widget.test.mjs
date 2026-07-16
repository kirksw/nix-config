import assert from "node:assert/strict";
import test from "node:test";
import { statusWidgetLine } from "../core/status-widget.ts";

test("renders OS status with the OS right-aligned and no zero unread badge", () => {
  const line = statusWidgetLine("OS", undefined, undefined, 0, "lifeOS", 60);
  assert.equal(line.endsWith("lifeOS"), true);
  assert.equal(line.includes("󰍡"), false);
  assert.equal(line.length, 60);
});

test("renders thread and factory context with unread messages", () => {
  const thread = statusWidgetLine("Thread", "continuum", undefined, 2, "lunarOS", 70);
  assert.match(thread, /󰭹 Thread  ·  @continuum  ·  󰍡 2/);
  assert.equal(thread.endsWith("lunarOS"), true);

  const factory = statusWidgetLine("Factory", "continuum", "wp-07", 1, "lifeOS", 70);
  assert.match(factory, / Factory  ·  @continuum  ·   wp-07  ·  󰍡 1/);
  assert.equal(factory.endsWith("lifeOS"), true);
});
