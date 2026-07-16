import * as path from "node:path";
import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { assertPolicyRead, assertPolicyWrite } from "../core/policy.ts";
import { readMarkdownOutcomes, writeOutcomeDocument } from "../core/markdown-store.ts";
import type { OutcomeRecord } from "../core/schema.js";
import { newId, nowIso } from "../core/store.js";

const OUTCOME_STATES: readonly OutcomeRecord["state"][] = ["planned", "in_progress", "done", "blocked", "archived"];
const OUTCOME_TRANSITIONS: Readonly<Record<OutcomeRecord["state"], readonly OutcomeRecord["state"][]>> = {
	planned: ["in_progress"],
	in_progress: ["done", "blocked", "archived"],
	done: [],
	blocked: [],
	archived: [],
};

function stripQuotes(value: string): string {
	return value.trim().replace(/^['"]|['"]$/g, "");
}

function validState(value: string): value is OutcomeRecord["state"] {
	return (OUTCOME_STATES as readonly string[]).includes(value);
}

export async function handleOutcome(args: string, agentos: AgentOsContext): Promise<string> {
	requireWritable(agentos);
	const value = args.trim();
	const add = value.match(/^add\s+([\s\S]*?)\s+--goal\s+([\s\S]+)$/);
	if (add) {
		const title = stripQuotes(add[1]);
		const goal = stripQuotes(add[2]);
		if (!title || !goal) throw new Error("usage: /agent-os outcome add <title> --goal <goal>");
		const now = nowIso();
		const outcome: OutcomeRecord = { id: newId("out"), type: "outcome", title, goal, state: "planned", createdAt: now, updatedAt: now };
		const file = path.join(agentos.workspacePath, "outcomes", `${outcome.id}.md`);
		assertPolicyWrite(agentos.policy, file);
		await writeOutcomeDocument(agentos.workspacePath, outcome);
		return `# Agent OS outcome added\n\n- ID: ${outcome.id}\n- Path: ${file}`;
	}

	const set = value.match(/^set\s+(\S+)\s+(\S+)$/);
	if (set) {
		const [, id, target] = set;
		if (!validState(target)) throw new Error(`invalid outcome state: ${target}`);
		const file = path.join(agentos.workspacePath, "outcomes", `${id}.md`);
		assertPolicyRead(agentos.policy, file);
		const outcome = (await readMarkdownOutcomes(agentos.workspacePath)).find((item) => item.id === id);
		if (!outcome) throw new Error(`outcome not found: ${id}`);
		if (!OUTCOME_TRANSITIONS[outcome.state].includes(target)) {
			throw new Error(`invalid outcome transition: ${outcome.state} -> ${target}`);
		}
		const now = nowIso();
		const updated: OutcomeRecord = {
			...outcome,
			state: target,
			updatedAt: now,
			...(target === "done" || target === "blocked" || target === "archived" ? { closedAt: now } : {}),
		};
		assertPolicyWrite(agentos.policy, file);
		await writeOutcomeDocument(agentos.workspacePath, updated);
		return `# Agent OS outcome updated\n\n- ID: ${updated.id}\n- State: ${updated.state}\n- Path: ${file}`;
	}

	throw new Error("usage: /agent-os outcome add <title> --goal <goal> | set <id> <state>");
}
