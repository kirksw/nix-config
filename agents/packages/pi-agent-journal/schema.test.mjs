import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("./index.ts", import.meta.url), "utf8");

test("tool parameters use a Bedrock-compatible top-level object schema", () => {
	assert.match(source, /const Parameters = Type\.Object\(\{/);
	assert.doesNotMatch(source, /const Parameters = Type\.Union\(/);
});
