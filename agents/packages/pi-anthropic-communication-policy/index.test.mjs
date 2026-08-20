import assert from "node:assert/strict";
import test from "node:test";
import registerPolicy, {
  COMMUNICATION_POLICY,
  isTargetClaudeModel,
} from "./index.ts";

function captureHandler() {
  let handler;
  registerPolicy({
    on(event, candidate) {
      if (event === "before_agent_start") handler = candidate;
    },
  });
  assert.equal(typeof handler, "function");
  return handler;
}

test("matches Fable, Sonnet, and Opus model identifiers across providers", () => {
  for (const modelId of [
    "claude-fable-5",
    "claude-sonnet-5",
    "claude-3-7-sonnet-20250219",
    "anthropic/claude-opus-4-8",
    "eu.anthropic.claude-sonnet-5",
  ]) {
    assert.equal(isTargetClaudeModel(modelId), true, modelId);
  }
});

test("does not match Haiku or unrelated models", () => {
  for (const modelId of [
    "claude-haiku-4-5",
    "gpt-5.6-terra",
    "sonnet-5",
    "fable",
  ]) {
    assert.equal(isTargetClaudeModel(modelId), false, modelId);
  }
});

test("injects the policy for target models", () => {
  const handler = captureHandler();
  const result = handler(
    { systemPrompt: "base prompt" },
    { model: { id: "claude-sonnet-5" } },
  );

  assert.equal(result.systemPrompt, `base prompt\n\n${COMMUNICATION_POLICY}`);
});

test("does not inject for non-target models", () => {
  const handler = captureHandler();
  assert.equal(
    handler({ systemPrompt: "base prompt" }, { model: { id: "claude-haiku-4-5" } }),
    undefined,
  );
  assert.equal(handler({ systemPrompt: "base prompt" }, { model: undefined }), undefined);
});

test("does not inject the policy twice", () => {
  const handler = captureHandler();
  assert.equal(
    handler(
      { systemPrompt: `base prompt\n\n${COMMUNICATION_POLICY}` },
      { model: { id: "claude-opus-5" } },
    ),
    undefined,
  );
});
