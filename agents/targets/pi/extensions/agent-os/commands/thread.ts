/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";
import type { AgentOsContext } from "../core/repo.ts";
import { requireWritable } from "../core/repo.ts";
import type { ThreadKind, ThreadRecord } from "../core/schema.ts";
import { slugify } from "../core/slug.ts";
import { newId, nowIso } from "../core/store.ts";
import {
	parseMarkdownDocument,
	readMarkdownThreads,
	updateMarkdownThread,
	writeThreadDocument,
} from "../core/markdown-store.ts";
import { renderThreadReadme } from "../render/thread-readme.ts";
import { initializeWorkspace, initializeThread } from "../core/layout.ts";

export type ActiveThreadSetter = (workspacePath: string, slug: string) => void;

function parseKind(args: string): { title: string; kind: ThreadKind } {
	const match = args.match(/(?:^|\s)--kind\s+(\S+)/);
	const rawKind = match?.[1] ?? "idea";
	const title = args
		.replace(/(?:^|\s)--kind\s+\S+/, " ")
		.trim()
		.replace(/^['"]|['"]$/g, "");
	if (!title)
		throw new Error("usage: /agent-os new-thread <title> --kind <kind>");
	return { title, kind: rawKind as ThreadKind };
}

async function uniqueSlug(workspacePath: string, title: string): Promise<string> {
	const base = slugify(title);
	const existing = new Set((await readMarkdownThreads(workspacePath)).map((t) => t.slug));
	if (!existing.has(base)) return base;
	for (let i = 2; i < 1000; i++) {
		const candidate = `${base}-${i}`;
		if (!existing.has(candidate)) return candidate;
	}
	throw new Error(`could not allocate unique slug for ${base}`);
}

export async function handleNewThread(
	args: string,
	agentos: AgentOsContext,
	setActive: ActiveThreadSetter,
): Promise<string> {
	requireWritable(agentos);
	if (agentos.mode !== "OS") {
		throw new Error(`${agentos.policy?.role} cannot create a thread outside OS mode`);
	}
	const { title, kind } = parseKind(args);
	await initializeWorkspace(agentos.workspacePath);
	const slug = await uniqueSlug(agentos.workspacePath, title);
	await initializeThread(agentos.workspacePath, slug);
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
		linear: { initiatives: [], projects: [] },
		kbs: [],
		repos: [],
	};

	await writeThreadDocument(agentos.workspacePath, thread);
	await renderThreadReadme(agentos.workspacePath, thread, [], []);
	setActive(agentos.workspacePath, slug);

	// Retroactive association: re-link inbox sessions that match this thread's project
	const linked = await reconcileThread(agentos, slug);

	const lines = [
		`# Agent OS thread created`,
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
	agentos: AgentOsContext,
	setActive: ActiveThreadSetter,
): Promise<string> {
	requireWritable(agentos);
	const slug = args.trim();
	if (!slug) throw new Error("usage: /agent-os thread <slug>");
	const threads = await readMarkdownThreads(agentos.workspacePath);
	const thread = threads.find((t) => t.slug === slug);
	if (!thread) throw new Error(`thread not found: ${slug}`);
	setActive(agentos.workspacePath, slug);
	return [
		`# Agent OS active thread`,
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
	agentos: AgentOsContext,
	threadSlug: string,
): Promise<ReconcileResult> {
	if (!agentos.workspacePath || !agentos.storePath) {
		return { sessions: 0, decisions: 0, blockers: 0, edges: 0 };
	}
	const workspacePath = agentos.workspacePath;
	const result: ReconcileResult = {
		sessions: 0,
		decisions: 0,
		blockers: 0,
		edges: 0,
	};

	// OKF Markdown has no legacy thread-map; the canonical project key is the thread slug.
	const projectSlugs = new Set([threadSlug]);

	// Markdown is authoritative for reconciliation. Move inbox documents without
	// rewriting their bodies or generated sections.
	const moveInboxDocuments = async (kind: "sessions" | "decisions" | "blockers" | "candidates"): Promise<void> => {
		const sourceDir = path.join(workspacePath, "inbox", kind);
		const targetDir = path.join(workspacePath, "threads", threadSlug, kind);
		await fs.mkdir(targetDir, { recursive: true });
		for (const file of await fs.readdir(sourceDir).catch(() => [])) {
			if (!file.endsWith(".md")) continue;
			const source = path.join(sourceDir, file);
			const document = parseMarkdownDocument(source, await fs.readFile(source, "utf8").catch(() => ""));
			const fm = document.frontmatter;
			const project =
				typeof fm.project_slug === "string"
					? fm.project_slug
					: typeof fm.project === "string"
						? fm.project
						: "";
			const linked =
				typeof fm.thread === "string"
					? fm.thread
					: typeof fm.threadId === "string"
						? fm.threadId
						: "";
			if (!(linked === "__inbox__" && projectSlugs.has(project))) continue;
			const target = path.join(targetDir, file);
			await fs.rename(source, target);
			await updateMarkdownThread(target, { thread: threadSlug });
			if (kind === "sessions") result.sessions++;
			else if (kind === "decisions") result.decisions++;
			else if (kind === "blockers") result.blockers++;
		}
	};
	await moveInboxDocuments("sessions");
	await moveInboxDocuments("decisions");
	await moveInboxDocuments("blockers");
	await moveInboxDocuments("candidates");

	return result;
}

/**
 * /agent-os reconcile [<slug>]
 * Manually re-link inbox sessions to threads.
 * Without a slug, runs for all threads.
 */
export async function handleReconcile(
	args: string,
	agentos: AgentOsContext,
): Promise<string> {
	requireWritable(agentos);
	if (agentos.mode !== "OS") {
		throw new Error(`${agentos.policy?.role} cannot reconcile outside OS mode`);
	}
	const targetSlug = args.trim();

	if (targetSlug) {
		const thread = (await readMarkdownThreads(agentos.workspacePath)).find(
			(candidate) => candidate.slug === targetSlug,
		);
		if (!thread) throw new Error(`thread not found: ${targetSlug}`);
		const result = await reconcileThread(agentos, targetSlug);
		return [
			`# Agent OS reconcile: ${targetSlug}`,
			"",
			`- Sessions re-linked: ${result.sessions}`,
			`- Decisions re-linked: ${result.decisions}`,
			`- Blockers re-linked: ${result.blockers}`,
			`- Edges updated: ${result.edges}`,
		].join("\n");
	}

	// Reconcile all threads
	const threads = await readMarkdownThreads(agentos.workspacePath);
	const lines = ["# Agent OS reconcile (all threads)", ""];
	const total = { sessions: 0, decisions: 0, blockers: 0, edges: 0 };
	for (const thread of threads) {
		if (!thread.slug || thread.slug === "__inbox__") continue;
		const result = await reconcileThread(agentos, thread.slug);
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
