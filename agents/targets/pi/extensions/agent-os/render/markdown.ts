/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";

export const GENERATED_START = "<!-- agent-os:generated:start -->";
export const GENERATED_END = "<!-- agent-os:generated:end -->";
const LEGACY_MARKERS = [
	["<!-- agentic-os:generated:start -->", "<!-- agentic-os:generated:end -->"],
	["<!-- lifeos:generated:start -->", "<!-- lifeos:generated:end -->"],
] as const;

export interface RenderResult {
	path: string;
	changed: boolean;
	warning?: string;
}

export function yamlString(value: string): string {
	return JSON.stringify(value);
}

export async function fileExists(file: string): Promise<boolean> {
	try {
		const stat = await fs.stat(file);
		return stat.isFile();
	} catch {
		return false;
	}
}

function markerPair(existing: string): readonly [string, string] {
	if (existing.includes(GENERATED_START) || existing.includes(GENERATED_END)) return [GENERATED_START, GENERATED_END];
	return [GENERATED_START, GENERATED_END];
}

function generatedBlock(content: string): string {
	const body = content.endsWith("\n") ? content.slice(0, -1) : content;
	return `${GENERATED_START}\n${body}\n${GENERATED_END}`;
}

async function writeAtomically(file: string, text: string): Promise<void> {
	const temporary = `${file}.tmp-${process.pid}-${Date.now()}`;
	await fs.writeFile(temporary, text, "utf8");
	await fs.rename(temporary, file);
}

export function replaceGeneratedBlock(
	existing: string,
	content: string,
): { text: string; changed: boolean; warning?: string } {
	const pair = markerPair(existing);
	const legacy = LEGACY_MARKERS.find(([start, end]) => existing.includes(start) || existing.includes(end));
	if (legacy) return { text: existing, changed: false, warning: "legacy generated markers require explicit migration" };
	const startCount = existing.split(pair[0]).length - 1;
	const endCount = existing.split(pair[1]).length - 1;
	if (startCount > 1 || endCount > 1 || LEGACY_MARKERS.some(([start, end]) => existing.split(start).length - 1 > 1 || existing.split(end).length - 1 > 1)) {
		return {
			text: existing,
			changed: false,
			warning: "duplicate generated markers; left file unchanged",
		};
	}

	const block = generatedBlock(content);
	const start = existing.indexOf(pair[0]);
	const end = existing.indexOf(pair[1]);
	if (start === -1 || end === -1 || end < start) {
		const separator = existing.endsWith("\n") ? "\n" : "\n\n";
		const text = `${existing}${separator}${block}\n`;
		return { text, changed: text !== existing };
	}

	const text = `${existing.slice(0, start)}${block}${existing.slice(end + pair[1].length)}`;
	return { text, changed: text !== existing };
}

export function migrateGeneratedMarkers(existing: string): { text: string; changed: boolean; warning?: string } {
	for (const [start, end] of LEGACY_MARKERS) {
		if (existing.includes(start) || existing.includes(end)) {
			if (existing.split(start).length - 1 !== 1 || existing.split(end).length - 1 !== 1) return { text: existing, changed: false, warning: "duplicate generated markers; left file unchanged" };
			return { text: existing.replace(start, GENERATED_START).replace(end, GENERATED_END), changed: true };
		}
	}
	return { text: existing, changed: false };
}

export async function writeGeneratedSection(
	file: string,
	fallback: string,
	content: string,
): Promise<RenderResult> {
	await fs.mkdir(path.dirname(file), { recursive: true });
	const existing = (await fileExists(file))
		? await fs.readFile(file, "utf8")
		: fallback;
	const next = replaceGeneratedBlock(existing, content);
	if (next.changed) await writeAtomically(file, next.text);
	return { path: file, changed: next.changed, warning: next.warning };
}
