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
import { writeJsonl } from "../core/store.js";
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

	// Retroactive association: re-link inbox sessions that match this thread's project
	const linked = await reconcileThread(lifeos, slug);

	const lines = [
		`# Thread OS thread created`,
		"",
		`- ${thread.title}`,
		`- Slug: ${thread.slug}`,
		`- Path: ${thread.path}`,
	];
	if (linked.sessions > 0) {
		lines.push(
			`- Retroactive: re-linked ${linked.sessions} session(s), ${linked.decisions} decision(s), ${linked.blockers} blocker(s) from inbox`,
		);
	}
	return lines.join("\n");
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

// --- Retroactive association ---

interface ReconcileResult {
	sessions: number;
	decisions: number;
	blockers: number;
	edges: number;
}

/**
 * Scan inbox sessions for ones matching this thread's project slug,
 * re-link them from __inbox__ to the given thread.
 *
 * Also updates decisions/blockers/edges that share those session IDs.
 * Moves session markdown notes from inbox/sessions/ to threads/<slug>/sessions/.
 */
async function reconcileThread(
	lifeos: ThreadOsContext,
	threadSlug: string,
): Promise<ReconcileResult> {
	if (!lifeos.workspacePath || !lifeos.storePath) {
		return { sessions: 0, decisions: 0, blockers: 0, edges: 0 };
	}
	const workspacePath = lifeos.workspacePath;
	const storePath = lifeos.storePath;

	const result: ReconcileResult = {
		sessions: 0,
		decisions: 0,
		blockers: 0,
		edges: 0,
	};

	// Load thread-map to find known project paths/slugs for this thread
	const indexPath = path.join(
		workspacePath,
		".lifeos",
		"index",
		"thread-map.json",
	);
	const projectSlugs = new Set<string>();
	try {
		const raw = await fs.readFile(indexPath, "utf8");
		const threadMap = JSON.parse(raw);
		const paths = threadMap.paths ?? {};
		const repos = threadMap.repos ?? {};
		for (const [key, val] of Object.entries(paths)) {
			const slug =
				typeof val === "string" ? val : (val as { default?: string })?.default;
			if (slug === threadSlug) {
				projectSlugs.add(slugify(path.basename(key)));
			}
		}
		for (const [key, val] of Object.entries(repos)) {
			const slug = Array.isArray(val)
				? val[0]
				: typeof val === "string"
					? val
					: (val as { default?: string })?.default;
			if (slug === threadSlug) {
				projectSlugs.add(slugify(key.split("/").pop() ?? ""));
			}
		}
	} catch {
		// no thread-map, no problem
	}

	// Also match by thread slug itself (common case: project dir matches thread slug)
	projectSlugs.add(threadSlug);

	// --- Sessions ---
	type SessionRecord = {
		id: string;
		thread?: string;
		project_slug?: string;
		session_id?: string;
	};
	const sessions = await readJsonl<SessionRecord>(storePath, "sessions");
	const matchedSessionIds = new Set<string>();
	let sessionsChanged = false;
	for (const s of sessions) {
		if (s.thread === "__inbox__" && projectSlugs.has(s.project_slug ?? "")) {
			s.thread = threadSlug;
			// Extract raw session id without "session:" prefix for matching decisions/blockers
			const rawId = (s.id ?? "").replace(/^session:/, "");
			matchedSessionIds.add(rawId);
			matchedSessionIds.add(s.id); // also keep full id for edge matching
			sessionsChanged = true;
			result.sessions++;
		}
	}
	if (sessionsChanged) {
		await writeJsonl(storePath, "sessions", sessions);
	}

	// --- Decisions ---
	type DecisionRecord = { id: string; thread?: string; session_id?: string };
	const decisions = await readJsonl<DecisionRecord>(storePath, "decisions");
	let decisionsChanged = false;
	for (const d of decisions) {
		if (d.thread === "__inbox__" && matchedSessionIds.has(d.session_id ?? "")) {
			d.thread = threadSlug;
			decisionsChanged = true;
			result.decisions++;
		}
	}
	if (decisionsChanged) {
		await writeJsonl(storePath, "decisions", decisions);
	}

	// --- Blockers ---
	type BlockerRecord = { id: string; thread?: string; session_id?: string };
	const blockers = await readJsonl<BlockerRecord>(storePath, "blockers");
	let blockersChanged = false;
	for (const b of blockers) {
		if (b.thread === "__inbox__" && matchedSessionIds.has(b.session_id ?? "")) {
			b.thread = threadSlug;
			blockersChanged = true;
			result.blockers++;
		}
	}
	if (blockersChanged) {
		await writeJsonl(storePath, "blockers", blockers);
	}

	// --- Edges ---
	type EdgeRecord = { id: string; from?: string; to?: string };
	const edges = await readJsonl<EdgeRecord>(storePath, "edges");
	let edgesChanged = false;
	const inboxThreadId = "thread:__inbox__";
	const newThreadId = `thread:${threadSlug}`;
	for (const e of edges) {
		if (e.to === inboxThreadId) {
			// Check if the session belongs to our matched set
			const sessionId = (e.from ?? "").replace("session:", "");
			if (matchedSessionIds.has(sessionId)) {
				e.to = newThreadId;
				edgesChanged = true;
				result.edges++;
			}
		}
	}
	if (edgesChanged) {
		await writeJsonl(storePath, "edges", edges);
	}

	// --- Move session markdown notes ---
	const inboxSessionsDir = path.join(workspacePath, "inbox", "sessions");
	const threadSessionsDir = path.join(
		workspacePath,
		"threads",
		threadSlug,
		"sessions",
	);
	try {
		await fs.mkdir(threadSessionsDir, { recursive: true });
		const files = await fs.readdir(inboxSessionsDir).catch(() => []);
		for (const file of files) {
			if (!file.endsWith(".md")) continue;
			// Match files that contain any of the project slugs or "inbox" + session IDs
			const lower = file.toLowerCase();
			const shouldMove = [...projectSlugs].some(
				(slug) => lower.includes(slug) || lower.includes("inbox"),
			);
			// Only move if the filename also matches a known session_id
			if (shouldMove) {
				const src = path.join(inboxSessionsDir, file);
				const dst = path.join(threadSessionsDir, file);
				await fs.rename(src, dst).catch(() => {});
			}
		}
	} catch {
		// non-fatal
	}

	return result;
}

/**
 * /thread-os reconcile [<slug>]
 * Manually re-link inbox sessions to threads.
 * Without a slug, runs for all threads.
 */
export async function handleReconcile(
	args: string,
	lifeos: ThreadOsContext,
): Promise<string> {
	requireWritable(lifeos);
	const targetSlug = args.trim();

	if (targetSlug) {
		const result = await reconcileThread(lifeos, targetSlug);
		return [
			`# Thread OS reconcile: ${targetSlug}`,
			"",
			`- Sessions re-linked: ${result.sessions}`,
			`- Decisions re-linked: ${result.decisions}`,
			`- Blockers re-linked: ${result.blockers}`,
			`- Edges updated: ${result.edges}`,
		].join("\n");
	}

	// Reconcile all threads
	const threads = await readJsonl<ThreadRecord>(lifeos.storePath, "threads");
	const lines = ["# Thread OS reconcile (all threads)", ""];
	const total = { sessions: 0, decisions: 0, blockers: 0, edges: 0 };
	for (const thread of threads) {
		if (!thread.slug || thread.slug === "__inbox__") continue;
		const result = await reconcileThread(lifeos, thread.slug);
		if (result.sessions > 0 || result.decisions > 0) {
			lines.push(
				`- ${thread.slug}: ${result.sessions} session(s), ${result.decisions} decision(s), ${result.blockers} blocker(s)`,
			);
		}
		total.sessions += result.sessions;
		total.decisions += result.decisions;
		total.blockers += result.blockers;
		total.edges += result.edges;
	}
	lines.push(
		"",
		`Total: ${total.sessions} session(s), ${total.decisions} decision(s), ${total.blockers} blocker(s)`,
	);
	return lines.join("\n");
}
