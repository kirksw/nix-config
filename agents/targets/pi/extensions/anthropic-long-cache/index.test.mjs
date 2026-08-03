import assert from "node:assert/strict";
import test from "node:test";

import anthropicLongCache, { applyOneHourTtl } from "./index.ts";

test("sets every nested ephemeral cache control to one hour", () => {
	const payload = {
		system: [
			{ type: "text", cache_control: { type: "ephemeral" } },
			{ type: "text", cache_control: { type: "ephemeral", ttl: "5m" } },
		],
		messages: [
			{
				content: [{ type: "tool_result", cache_control: { type: "persistent", ttl: "5m" } }],
			},
		],
	};

	applyOneHourTtl(payload);

	assert.equal(payload.system[0].cache_control.ttl, "1h");
	assert.equal(payload.system[1].cache_control.ttl, "1h");
	assert.equal(payload.messages[0].content[0].cache_control.ttl, "5m");
});

test("rewrites requests only for the direct Anthropic Messages API", () => {
	let handler;
	anthropicLongCache({
		on(event, registeredHandler) {
			assert.equal(event, "before_provider_request");
			handler = registeredHandler;
		},
	});
	assert.ok(handler);

	const anthropicPayload = { cache_control: { type: "ephemeral" } };
	const result = handler(
		{ payload: anthropicPayload },
		{ model: { provider: "anthropic", api: "anthropic-messages", id: "claude-opus-5" } },
	);
	assert.equal(anthropicPayload.cache_control.ttl, "1h");
	assert.equal(result, anthropicPayload);

	for (const model of [
		{ provider: "anthropic-proxy", api: "anthropic-messages", id: "claude-opus-5" },
		{ provider: "anthropic", api: "openai-responses", id: "claude-opus-5" },
		undefined,
	]) {
		const payload = { cache_control: { type: "ephemeral" } };
		assert.equal(handler({ payload }, { model }), undefined);
		assert.deepEqual(payload, { cache_control: { type: "ephemeral" } });
	}
});
