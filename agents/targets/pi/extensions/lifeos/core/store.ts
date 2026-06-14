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
	return records;
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
