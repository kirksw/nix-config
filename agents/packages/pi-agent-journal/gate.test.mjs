import assert from "node:assert/strict";
import test from "node:test";
import {
	createJournalGateState,
	isJournalRantToolCall,
	observeToolResult,
} from "./gate.ts";

function observe(state, isError, isRant = false) {
	return observeToolResult(state, isError, isRant);
}

test("requires a rant after three consecutive failures and notices only the threshold", () => {
	let state = createJournalGateState();
	let result = observe(state, true);
	assert.equal(result.thresholdReached, false);
	result = observe(result.state, true);
	assert.equal(result.thresholdReached, false);
	result = observe(result.state, true);
	assert.equal(result.thresholdReached, true);
	assert.deepEqual(result.state, { consecutiveFailures: 3, journalRequired: true });
	result = observe(result.state, true);
	assert.equal(result.thresholdReached, false);
});

test("successful ordinary results reset only the counter, while a successful rant clears the gate", () => {
	let state = createJournalGateState();
	state = observe(observe(observe(state, true).state, true).state, true).state;
	let result = observe(state, false);
	assert.deepEqual(result.state, { consecutiveFailures: 0, journalRequired: true });
	result = observe(result.state, false, true);
	assert.deepEqual(result.state, { consecutiveFailures: 0, journalRequired: false });

	state = observe(observe(observe(createJournalGateState(), true).state, true).state, true).state;
	result = observe(state, true, true);
	assert.deepEqual(result.state, { consecutiveFailures: 4, journalRequired: true });
});

test("only an agent_journal rant is an allowed gate-clearing call", () => {
	assert.equal(isJournalRantToolCall("agent_journal", { action: "rant", text: "blocked" }), true);
	assert.equal(isJournalRantToolCall("agent_journal", { action: "list" }), false);
	assert.equal(isJournalRantToolCall("agent_journal", null), false);
	assert.equal(isJournalRantToolCall("search", { action: "rant" }), false);
});
