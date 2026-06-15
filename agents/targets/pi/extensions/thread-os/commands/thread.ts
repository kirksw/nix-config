/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";
import type { ThreadOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import {
	THREAD_KINDS,
	type ThreadKind,
	type ThreadRecord,
} from "../core/schema.js";
import { slugify } from "../core/slug.js";
import { appendRecord, newId, nowIso, readJsonl } from "../core/store.js";
import { renderThreadReadme } from "../render/thread-readme.js";

export type ActiveThreadSetter = (workspacePath: string, slug: string) => void;

function parseKind(args: string): { title: string; kind: ThreadKind } {
	const match = args.match(/(?:^|\s)--kind\s+(\S+)/);
	const rawKind = match?.[1] ?? "idea";
	if (!THREAD_KINDS.includes(rawKind as ThreadKind)) {
		throw new Error(
			`invalid kind '${rawKind}' (expected ${THREAD_KINDS.join(" | ")})`,
		);
	}
	const title = args
		.replace(/(?:^|\s)--kind\s+\S+/, " ")
		.trim()
		.replace(/^['"]|['"]$/g, "");
	if (!title)
		throw new Error("usage: /thread-os new-thread <title> --kind <kind>");
	return { title, kind: rawKind as ThreadKind };
}

async function uniqueSlug(storePath: string, title: string): Promise<string> {
	const base = slugify(title);
	const existing = new Set(
		(await readJsonl<ThreadRecord>(storePath, "threads")).map((t) => t.slug),
	);
	if (!existing.has(base)) return base;
	for (let i = 2; i < 1000; i++) {
		const candidate = `${base}-${i}`;
		if (!existing.has(candidate)) return candidate;
	}
	throw new Error(`could not allocate unique slug for ${base}`);
}

export async function handleNewThread(
	args: string,
	lifeos: ThreadOsContext,
	setActive: ActiveThreadSetter,
): Promise<string> {
	requireWritable(lifeos);
	const { title, kind } = parseKind(args);
	const slug = await uniqueSlug(lifeos.storePath, title);
	const now = nowIso();
	const thread: ThreadRecord = {
		id: newId("thr"),
		type: "thread",
		createdAt: now,
		updatedAt: now,
		slug,
		title,
		kind,
		status: "active",
		stage: "new",
		path: path.join("threads", slug),
		impact: 5,
		confidence: 5,
		urgency: 5,
		effort: 5,
		salience: 5,
	};

	await appendRecord(lifeos.storePath, "threads", thread);
	await fs.mkdir(path.join(lifeos.workspacePath, thread.path, "artifacts"), {
		recursive: true,
	});
	await renderThreadReadme(lifeos.workspacePath, thread, [], []);
	setActive(lifeos.workspacePath, slug);

	return [
		`# Thread OS thread created`,
		"",
		`- ${thread.title}`,
		`- Slug: ${thread.slug}`,
		`- Path: ${thread.path}`,
	].join("\n");
}

export async function handleThread(
	args: string,
	lifeos: ThreadOsContext,
	setActive: ActiveThreadSetter,
): Promise<string> {
	requireWritable(lifeos);
	const slug = args.trim();
	if (!slug) throw new Error("usage: /thread-os thread <slug>");
	const threads = await readJsonl<ThreadRecord>(lifeos.storePath, "threads");
	const thread = threads.find((t) => t.slug === slug);
	if (!thread) throw new Error(`thread not found: ${slug}`);
	setActive(lifeos.workspacePath, slug);
	return [
		`# Thread OS active thread`,
		"",
		`- ${thread.title}`,
		`- Slug: ${thread.slug}`,
		`- Status: ${thread.status}`,
		`- Stage: ${thread.stage}`,
	].join("\n");
}
