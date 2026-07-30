/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";
import type { AgentOsMode } from "./mode.ts";
import { normalizeTaskId, runtimeFilePath } from "./runtime.ts";

export interface RuntimeMigrationReport {
	success: boolean;
	removed: boolean;
	migratedRecords: number;
	unsupported: string[];
}

interface MigrationRecord {
	file: string;
	line: number;
	record: Record<string, unknown>;
	target: string;
	id?: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function mode(value: unknown): AgentOsMode | undefined {
	if (value === "OS" || value === "Thread" || value === "Factory") return value;
	return undefined;
}

function scopeFor(
	thread: unknown,
	task: unknown,
): { mode: AgentOsMode; thread?: string; task?: string } | undefined {
	if (task !== undefined && task !== null && !thread) return undefined;
	if (!thread) return { mode: "OS" };
	if (typeof thread !== "string" || thread.includes("/") || thread.includes("\\")) return undefined;
	const normalizedTask = typeof task === "string"
		? normalizeTaskId(task)
		: undefined;
	if (task !== undefined && task !== null && !normalizedTask) return undefined;
	return normalizedTask
		? { mode: "Factory", thread, task: normalizedTask }
		: { mode: "Thread", thread };
}

function messageScope(record: Record<string, unknown>):
	| { mode: AgentOsMode; thread?: string; task?: string }
	| undefined {
	const to = record.to;
	if (!isRecord(to)) return undefined;
	const recipientMode = mode(to.mode);
	if (!recipientMode) return undefined;
	if (recipientMode === "OS") {
		return to.thread === undefined && to.task === undefined ? { mode: "OS" } : undefined;
	}
	if (typeof to.thread !== "string" || to.thread.includes("/") || to.thread.includes("\\")) return undefined;
	const task = recipientMode === "Factory" ? normalizeTaskId(typeof to.task === "string" ? to.task : undefined) : undefined;
	if (recipientMode === "Factory" && !task) return undefined;
	if (recipientMode === "Thread" && to.task !== undefined) return undefined;
	return { mode: recipientMode, thread: to.thread, task };
}

async function appendUnique(file: string, records: MigrationRecord[]): Promise<number> {
	const existing = await fs.readFile(file, "utf8").catch(() => "");
	const existingIds = new Set<string>();
	const existingLines = new Set<string>(existing.split("\n").filter((line) => line.trim()));
	for (const line of existingLines) {
		try {
			const parsed = JSON.parse(line) as Record<string, unknown>;
			if (typeof parsed.id === "string") existingIds.add(parsed.id);
		} catch {
			// Existing runtime lines are left untouched.
		}
	}
	const fresh = records.filter((entry) =>
		(entry.id ? !existingIds.has(entry.id) : !existingLines.has(JSON.stringify(entry.record))),
	);
	if (fresh.length === 0) return 0;
	await fs.mkdir(path.dirname(file), { recursive: true });
	await fs.appendFile(file, `${fresh.map((entry) => JSON.stringify(entry.record)).join("\n")}\n`, "utf8");
	return fresh.length;
}

/** Migrate legacy operational JSONL without creating canonical Markdown records. */
export async function migrateLegacyRuntime(workspacePath: string): Promise<RuntimeMigrationReport> {
	const legacyRoot = path.join(workspacePath, ".lifeos", "db");
	const names = await fs.readdir(legacyRoot).catch(() => []);
	if (names.length === 0) {
		await fs.rm(path.dirname(legacyRoot), { recursive: true, force: true });
		return { success: true, removed: true, migratedRecords: 0, unsupported: [] };
	}

	const records: MigrationRecord[] = [];
	const unsupported: string[] = [];
	for (const name of names) {
		const source = path.join(legacyRoot, name);
		const stat = await fs.stat(source).catch(() => undefined);
		if (!stat?.isFile()) {
			unsupported.push(`${name}: unsupported legacy entry`);
			continue;
		}
		const text = await fs.readFile(source, "utf8").catch(() => "");
		if (!text.trim()) continue;
		if (name !== "agent-os-messages.jsonl" && name !== "agent-os-events.jsonl") {
			unsupported.push(`${name}: unsupported non-empty legacy store`);
			continue;
		}
		for (const [index, line] of text.split("\n").entries()) {
			if (!line.trim()) continue;
			let parsed: unknown;
			try {
				parsed = JSON.parse(line);
			} catch {
				unsupported.push(`${name}:${index + 1}: invalid JSON`);
				continue;
			}
			if (!isRecord(parsed)) {
				unsupported.push(`${name}:${index + 1}: expected JSON object`);
				continue;
			}
			const scope = name === "agent-os-messages.jsonl"
				? messageScope(parsed)
				: scopeFor(parsed.thread, parsed.task);
			if (!scope) {
				unsupported.push(`${name}:${index + 1}: unsupported runtime scope`);
				continue;
			}
			if (name === "agent-os-messages.jsonl" &&
				(typeof parsed.id !== "string" || typeof parsed.body !== "string" || !isRecord(parsed.from))) {
				unsupported.push(`${name}:${index + 1}: invalid mailbox record`);
				continue;
			}
			if (name === "agent-os-events.jsonl" && typeof parsed.type !== "string") {
				unsupported.push(`${name}:${index + 1}: invalid lifecycle event`);
				continue;
			}
			records.push({
				file: name,
				line: index + 1,
				record: parsed,
				target: runtimeFilePath(workspacePath, name === "agent-os-messages.jsonl" ? "mailbox" : "events", scope),
				id: name === "agent-os-messages.jsonl" ? parsed.id as string : undefined,
			});
		}
	}

	if (unsupported.length > 0) {
		return { success: false, removed: false, migratedRecords: 0, unsupported };
	}
	try {
		const grouped = new Map<string, MigrationRecord[]>();
		for (const record of records) grouped.set(record.target, [...(grouped.get(record.target) ?? []), record]);
		let migratedRecords = 0;
		for (const [target, entries] of grouped) migratedRecords += await appendUnique(target, entries);
		await fs.rm(path.dirname(legacyRoot), { recursive: true, force: true });
		return { success: true, removed: true, migratedRecords, unsupported: [] };
	} catch (error) {
		return {
			success: false,
			removed: false,
			migratedRecords: 0,
			unsupported: [`migration failed: ${(error as Error).message}`],
		};
	}
}
