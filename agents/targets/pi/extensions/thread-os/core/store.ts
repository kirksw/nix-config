/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";
import type {
	BlockerRecord,
	CandidateRecord,
	DecisionRecord,
	EdgeRecord,
	LifeOsData,
	LifeOsRecord,
	MetricRecord,
	StoreFile,
	ThreadRecord,
} from "./schema.js";
import { STORE_FILES } from "./schema.js";

export function nowIso(): string {
	return new Date().toISOString();
}

export function newId(prefix: string): string {
	return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export async function ensureStore(storePath: string): Promise<void> {
	await fs.mkdir(storePath, { recursive: true });
	await Promise.all(
		STORE_FILES.map(async (name) => {
			const file = path.join(storePath, `${name}.jsonl`);
			try {
				await fs.stat(file);
			} catch {
				await fs.writeFile(file, "", "utf8");
			}
		}),
	);
}

export async function appendRecord<T extends LifeOsRecord>(
	storePath: string,
	file: StoreFile,
	record: T,
): Promise<T> {
	await ensureStore(storePath);
	await fs.appendFile(
		path.join(storePath, `${file}.jsonl`),
		`${JSON.stringify(record)}\n`,
		"utf8",
	);
	return record;
}

export async function writeJsonl<T>(
	storePath: string,
	file: StoreFile,
	records: T[],
): Promise<void> {
	await ensureStore(storePath);
	const body = records.map((r) => JSON.stringify(r)).join("\n") + "\n";
	await fs.writeFile(path.join(storePath, `${file}.jsonl`), body, "utf8");
}

/**
 * Deduplicate records by `id`, keeping the last occurrence.
 * This makes the JSONL store safe for append-updated records (e.g. thread
 * timestamp updates from the session-end hook). When all ids are unique the
 * function is a no-op.
 */
export function dedupById<T>(records: T[]): T[] {
	const latest = new Map<string, T>();
	for (const record of records) {
		const id = (record as { id?: string })?.id;
		if (typeof id === "string") latest.set(id, record);
	}
	if (latest.size === 0) return records;
	const result: T[] = [];
	const emitted = new Set<string>();
	for (const record of records) {
		const id = (record as { id?: string })?.id;
		if (typeof id === "string") {
			if (!emitted.has(id)) {
				emitted.add(id);
				result.push(latest.get(id)!);
			}
		} else {
			result.push(record);
		}
	}
	return result;
}

export async function readJsonl<T>(
	storePath: string,
	file: StoreFile,
): Promise<T[]> {
	await ensureStore(storePath);
	const body = await fs.readFile(path.join(storePath, `${file}.jsonl`), "utf8");
	const records: T[] = [];
	for (const [index, line] of body.split("\n").entries()) {
		const trimmed = line.trim();
		if (!trimmed) continue;
		try {
			records.push(JSON.parse(trimmed) as T);
		} catch (err) {
			throw new Error(
				`${file}.jsonl line ${index + 1} is invalid JSON: ${(err as Error).message}`,
			);
		}
	}
	return dedupById(records);
}

export async function readData(storePath: string): Promise<LifeOsData> {
	const [threads, metrics, edges, blockers, candidates, decisions] =
		await Promise.all([
			readJsonl<ThreadRecord>(storePath, "threads"),
			readJsonl<MetricRecord>(storePath, "metrics"),
			readJsonl<EdgeRecord>(storePath, "edges"),
			readJsonl<BlockerRecord>(storePath, "blockers"),
			readJsonl<CandidateRecord>(storePath, "candidates"),
			readJsonl<DecisionRecord>(storePath, "decisions"),
		]);
	return { threads, metrics, edges, blockers, candidates, decisions };
}
