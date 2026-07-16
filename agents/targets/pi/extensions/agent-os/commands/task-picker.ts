/// <reference path="../types.d.ts" />
import * as path from "node:path";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AgentOsContext } from "../core/repo.js";
import { listTasks, type TaskRecord } from "../core/task.js";
import type { ActiveBinding } from "./task.js";
import { fuzzyScore, loadPiTui, type PiTui, type Theme } from "./thread-picker.js";

type TaskChoice =
	| { kind: "bind"; value: string }
	| { kind: "create"; value: string };

export class TaskPicker {
	public onSelect?: (choice: TaskChoice) => void;
	public onCancel?: () => void;
	public requestRender?: () => void;

	private query = "";
	private searching = false;
	private creating = false;
	private selected = 0;
	private filteredCache: TaskRecord[] | null = null;
	private readonly packages: TaskRecord[];
	private readonly activeTask: string | undefined;
	private readonly theme: Theme;
	private readonly tk: PiTui;

	constructor(
		packages: TaskRecord[],
		activeTask: string | undefined,
		theme: Theme,
		tk: PiTui,
	) {
		this.packages = packages;
		this.activeTask = activeTask;
		this.theme = theme;
		this.tk = tk;
		if (activeTask) {
			const idx = packages.findIndex(
				(pkg) => path.resolve(pkg.path) === path.resolve(activeTask),
			);
			if (idx >= 0) this.selected = idx;
		}
	}

	private filtered(): TaskRecord[] {
		if (this.filteredCache) return this.filteredCache;
		const query = this.query.trim().toLowerCase();
		if (!query) {
			this.filteredCache = this.packages;
		} else {
			this.filteredCache = this.packages
				.map((pkg, index) => ({
					pkg,
					index,
					score: Math.max(fuzzyScore(query, pkg.id), fuzzyScore(query, pkg.title)),
				}))
				.filter((item) => item.score >= 0)
				.sort((a, b) => b.score - a.score || a.index - b.index)
				.map((item) => item.pkg);
		}
		return this.filteredCache;
	}

	private rerender(): void {
		this.filteredCache = null;
		this.requestRender?.();
	}

	private move(delta: number): void {
		const last = this.filtered().length;
		this.selected = Math.max(0, Math.min(last, this.selected + delta));
		this.rerender();
	}

	handleInput(data: string): void {
		const { matchesKey, Key } = this.tk;
		if (this.creating) {
			if (matchesKey(data, Key.enter)) {
				const title = this.query.trim();
				if (title) this.onSelect?.({ kind: "create", value: title });
				return;
			}
			if (matchesKey(data, Key.escape)) {
				this.creating = false;
				this.query = "";
				this.selected = this.filtered().length;
				this.rerender();
				return;
			}
			if (matchesKey(data, Key.backspace)) {
				this.query = this.query.slice(0, -1);
				this.rerender();
				return;
			}
			if (data.length === 1 && data.charCodeAt(0) >= 0x20 && data.charCodeAt(0) < 0x7f) {
				this.query += data;
				this.rerender();
			}
			return;
		}

		const packages = this.filtered();
		if (matchesKey(data, Key.enter)) {
			if (this.selected === packages.length) {
				this.creating = true;
				this.query = "";
				this.rerender();
			} else if (packages[this.selected]) {
				this.onSelect?.({ kind: "bind", value: packages[this.selected]!.id });
			}
			return;
		}
		if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n"))) {
			this.move(1);
			return;
		}
		if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p"))) {
			this.move(-1);
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
			if (data.length === 1 && data.charCodeAt(0) >= 0x20 && data.charCodeAt(0) < 0x7f) {
				this.query += data;
				this.selected = 0;
				this.rerender();
			}
			return;
		}
		if (matchesKey(data, "j")) this.move(1);
		else if (matchesKey(data, "k")) this.move(-1);
		else if (matchesKey(data, "g")) {
			this.selected = 0;
			this.rerender();
		} else if (matchesKey(data, "G") || matchesKey(data, Key.shift("g"))) {
			this.selected = packages.length;
			this.rerender();
		} else if (matchesKey(data, Key.slash)) {
			this.searching = true;
			this.query = "";
			this.selected = 0;
			this.rerender();
		} else if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
			this.onCancel?.();
		}
	}

	render(width: number): string[] {
		const fg = this.theme.fg.bind(this.theme);
		const bold = this.theme.bold.bind(this.theme);
		const { truncateToWidth, visibleWidth } = this.tk;
		const packages = this.filtered();
		if (this.selected > packages.length) this.selected = packages.length;
		const W = { id: 32, status: 12 };
		const gap = " ";
		const titleW = Math.max(12, width - (2 + W.id + W.status) - 3);
		const pad = (value: string, size: number) => value + " ".repeat(Math.max(0, size - visibleWidth(value)));
		const cell = (value: string, size: number, color: string, isBold = false) => {
			let text = truncateToWidth(value, size);
			if (isBold) text = bold(text);
			return pad(fg(color, text), size);
		};
		const lines: string[] = [];
		lines.push(`${fg("accent", bold("# agentOS tasks"))}${fg("muted", `  ${packages.length}/${this.packages.length}`)}`);
		if (this.creating) {
			lines.push(`${fg("accent", "Spar title: ")}${fg("text", this.query)}${fg("dim", "▏")}`);
		} else {
			if (this.searching) lines.push(`${fg("accent", "/")}${fg("text", this.query)}${fg("dim", "▏")}`);
			lines.push(`  ${cell("id", W.id, "dim")} ${cell("status", W.status, "dim")} ${cell("title", titleW, "dim")}`);
			for (let index = 0; index < packages.length; index += 1) {
				const pkg = packages[index]!;
				const selected = index === this.selected;
				const active = this.activeTask && path.resolve(pkg.path) === path.resolve(this.activeTask);
				const marker = selected ? fg("accent", "▸ ") : active ? fg("accent", "● ") : "  ";
				lines.push(truncateToWidth(`${marker}${cell(pkg.id, W.id, selected ? "accent" : "text", selected)} ${cell(pkg.status, W.status, "muted")} ${cell(`${pkg.title}${active ? " ←" : ""}`, titleW, selected ? "accent" : "text", selected)}`, width));
			}
			const action = this.selected === packages.length;
			lines.push(truncateToWidth(`${action ? fg("accent", "▸ ") : "  "}${fg(action ? "accent" : "muted", "✦ spar / create draft")}`, width));
		}
		lines.push(fg("dim", this.creating ? "  type title · enter create draft · esc back" : "  / search · j/k ↑↓ C-n/C-p · g/G · enter select · esc cancel"));
		return lines.map((line) => truncateToWidth(line, width));
	}
}

export async function pickTask(
	ctx: ExtensionContext,
	agentos: AgentOsContext,
	active: ActiveBinding,
): Promise<TaskChoice | undefined> {
	if (!ctx.ui.custom) {
		ctx.ui.notify("Task picker requires TUI mode", "warning");
		return undefined;
	}
	if (!agentos.workspacePath || !active.thread) {
		ctx.ui.notify("Select a thread before choosing a task", "warning");
		return undefined;
	}
	const tk = await loadPiTui();
	if (!tk) {
		ctx.ui.notify("Task picker unavailable (pi-tui not found)", "error");
		return undefined;
	}
	const packages = await listTasks(agentos.workspacePath, active.thread);
	return ctx.ui.custom<TaskChoice | undefined>((tui, theme, _keybindings, done) => {
		const picker = new TaskPicker(packages, active.task, theme, tk);
		picker.requestRender = () => tui.requestRender();
		picker.onSelect = done;
		picker.onCancel = () => done(undefined);
		return picker;
	});
}
