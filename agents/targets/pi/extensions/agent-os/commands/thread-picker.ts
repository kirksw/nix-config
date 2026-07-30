/// <reference path="../types.d.ts" />
import * as path from "node:path";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AgentOsContext } from "../core/repo.ts";
import type { ThreadRecord } from "../core/schema.ts";
import { readMarkdownThreads } from "../core/markdown-store.ts";

export type Theme = {
	fg(color: string, text: string): string;
	bold(text: string): string;
};

export interface PiTui {
	matchesKey(data: string, key: string): boolean;
	Key: {
		up: string;
		down: string;
		enter: string;
		escape: string;
		backspace: string;
		slash: string;
		ctrl(c: string): string;
		shift(c: string): string;
	};
	truncateToWidth(s: string, w: number, ellipsis?: string): string;
	visibleWidth(s: string): number;
}

// Resolve pi-tui robustly: jiti's default walk won't find it from extensions/,
// so fall back to the profile's npm/node_modules (PI_CODING_AGENT_DIR).
let piTui: PiTui | null = null;
export async function loadPiTui(): Promise<PiTui | null> {
	if (piTui) return piTui;
	try {
		piTui = await import("@earendil-works/pi-tui");
		return piTui;
	} catch {}
	const dir = process.env.PI_CODING_AGENT_DIR;
	if (dir) {
		try {
			piTui = await import(
				path.join(dir, "npm/node_modules/@earendil-works/pi-tui/dist/index.ts")
			);
			return piTui;
		} catch {}
	}
	return null;
}

// Subsequence fuzzy score: higher = better (contiguous runs bonus). -1 = no match.
export function fuzzyScore(query: string, text: string): number {
	const q = query.toLowerCase();
	const t = text.toLowerCase();
	if (!q) return 0;
	let qi = 0;
	let score = 0;
	let prev = -2;
	for (let ti = 0; ti < t.length && qi < q.length; ti++) {
		if (t[ti] === q[qi]) {
			score += ti === prev + 1 ? 5 : 1;
			prev = ti;
			qi++;
		}
	}
	return qi === q.length ? score : -1;
}

export class ThreadPicker {
	public onSelect?: (slug: string) => void;
	public onCancel?: () => void;
	public requestRender?: () => void;

	private query = "";
	private searching = false;
	private selected = 0;
	private filteredCache: ThreadRecord[] | null = null;
	private readonly threads: ThreadRecord[];
	private readonly activeThread: string | undefined;
	private readonly theme: Theme;
	private readonly tk: PiTui;

	constructor(
		threads: ThreadRecord[],
		activeThread: string | undefined,
		theme: Theme,
		tk: PiTui,
	) {
		this.threads = threads;
		this.activeThread = activeThread;
		this.theme = theme;
		this.tk = tk;
		// Start on the active thread if present.
		if (activeThread) {
			const idx = threads.findIndex((t) => t.slug === activeThread);
			if (idx >= 0) this.selected = idx;
		}
	}

	private filtered(): ThreadRecord[] {
		if (this.filteredCache) return this.filteredCache;
		const q = this.query.trim().toLowerCase();
		if (!q) {
			this.filteredCache = this.threads;
		} else {
			this.filteredCache = this.threads
				.map((th, i) => ({
					th,
					i,
					s: Math.max(fuzzyScore(q, th.slug), fuzzyScore(q, th.title)),
				}))
				.filter((x) => x.s >= 0)
				.sort((a, b) => b.s - a.s || a.i - b.i)
				.map((x) => x.th);
		}
		return this.filteredCache;
	}

	private rerender(): void {
		this.filteredCache = null;
		this.requestRender?.();
	}

	invalidate(): void {
		this.filteredCache = null;
		this.requestRender?.();
	}

	handleInput(data: string): void {
		const { matchesKey, Key } = this.tk;
		const f = this.filtered();
		const last = f.length - 1;
		const move = (d: number) => {
			this.selected = Math.max(0, Math.min(last, this.selected + d));
			this.rerender();
		};

		if (matchesKey(data, Key.enter)) {
			this.onSelect?.(f[this.selected]?.slug);
			return;
		}
		if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n"))) {
			move(1);
			return;
		}
		if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p"))) {
			move(-1);
			return;
		}

		if (this.searching) {
			if (matchesKey(data, Key.escape)) {
				this.searching = false;
				this.query = "";
				this.selected = 0;
				this.rerender();
				return;
			}
			if (matchesKey(data, Key.backspace)) {
				this.query = this.query.slice(0, -1);
				this.selected = 0;
				this.rerender();
				return;
			}
			if (data.length === 1) {
				const c = data.charCodeAt(0);
				if (c >= 0x20 && c < 0x7f) {
					this.query += data;
					this.selected = 0;
					this.rerender();
					return;
				}
			}
			return;
		}

		// Browse mode: letter nav + enter search.
		if (matchesKey(data, "j")) {
			move(1);
		} else if (matchesKey(data, "k")) {
			move(-1);
		} else if (matchesKey(data, "g")) {
			this.selected = 0;
			this.rerender();
		} else if (matchesKey(data, "G") || matchesKey(data, Key.shift("g"))) {
			this.selected = last;
			this.rerender();
		} else if (matchesKey(data, Key.slash)) {
			this.searching = true;
			this.query = "";
			this.rerender();
		} else if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
			this.onCancel?.();
		}
	}

	render(width: number): string[] {
		const fg = this.theme.fg.bind(this.theme);
		const bold = this.theme.bold.bind(this.theme);
		const { truncateToWidth, visibleWidth } = this.tk;
		const f = this.filtered();
		if (this.selected > f.length - 1) this.selected = Math.max(0, f.length - 1);

		const W = { slug: 28, kind: 9, status: 9, stage: 20 };
		const gaps = 5;
		const titleW = Math.max(8, width - (2 + W.slug + W.kind + W.status + W.stage) - gaps);
		const gap = " ";
		const padTo = (s: string, w: number) =>
			s + " ".repeat(Math.max(0, w - visibleWidth(s)));
		const cell = (raw: string, w: number, color: string | null, b = false) => {
			const trunc = truncateToWidth(String(raw ?? ""), w);
			let s = trunc;
			if (color) {
				if (b) s = bold(s);
				s = fg(color, s);
			}
			return padTo(s, w);
		};

		const lines: string[] = [];
		lines.push(
			`${fg("accent", bold("# agentOS threads"))}${fg(
				"muted",
				`  ${f.length}/${this.threads.length}`,
			)}`,
		);
		if (this.searching) {
			lines.push(`${fg("accent", "/")}${fg("text", this.query)}${fg("dim", "▏")}`);
		}
		lines.push(
			"  " +
				cell("slug", W.slug, "dim") +
				gap +
				cell("kind", W.kind, "dim") +
				gap +
				cell("status", W.status, "dim") +
				gap +
				cell("stage", W.stage, "dim") +
				gap +
				cell("title", titleW, "dim"),
		);

		if (f.length === 0) {
			lines.push(fg("muted", "  no matches — esc to clear"));
		} else {
			const maxRows = 15;
			let start = 0;
			if (f.length > maxRows) {
				start = Math.max(0, this.selected - Math.floor(maxRows / 2));
				start = Math.min(start, f.length - maxRows);
			}
			const end = Math.min(f.length, start + maxRows);
			for (let i = start; i < end; i++) {
				const th = f[i]!;
				const sel = i === this.selected;
				const isActive = th.slug === this.activeThread;
				const marker = sel
					? fg("accent", "▸ ")
					: isActive
						? fg("accent", "● ")
						: "  ";
				const titleRaw = isActive ? `${th.title} ←` : th.title;
				const row =
					marker +
					cell(th.slug, W.slug, sel ? "accent" : "text", sel) +
					gap +
					cell(th.kind, W.kind, "muted") +
					gap +
					cell(th.status, W.status, "muted") +
					gap +
					cell(th.stage, W.stage, "muted") +
					gap +
					cell(titleRaw, titleW, sel ? "accent" : "text");
				lines.push(truncateToWidth(row, width));
			}
		}

		lines.push(
			fg(
				"dim",
				"  / search · j/k ↑↓ C-n/C-p · g/G · enter select · esc cancel",
			),
		);
		return lines.map((l) => truncateToWidth(l, width));
	}
}

export async function pickThread(
	ctx: ExtensionContext,
	agentos: AgentOsContext,
	getActive: (workspacePath: string | null) => string | undefined,
): Promise<string | undefined> {
	if (!ctx.ui.custom) {
		ctx.ui.notify("Thread picker requires TUI mode", "warning");
		return undefined;
	}
	if (!agentos.storePath) {
		ctx.ui.notify("agentOS workspace not resolved", "warning");
		return undefined;
	}
	const tk = await loadPiTui();
	if (!tk) {
		ctx.ui.notify("Thread picker unavailable (pi-tui not found)", "error");
		return undefined;
	}
	const threads = await readMarkdownThreads(agentos.workspacePath);
	if (threads.length === 0) {
		ctx.ui.notify("No agentOS threads found", "warning");
		return undefined;
	}
	const active =
		getActive(agentos.workspacePath ?? "") ?? process.env.AGENT_OS_THREAD_ID;
	return ctx.ui.custom<string | undefined>((tui, theme, _keybindings, done) => {
		const picker = new ThreadPicker(threads, active, theme, tk);
		picker.requestRender = () => tui.requestRender();
		picker.onSelect = done;
		picker.onCancel = () => done(undefined);
		return picker;
	});
}
