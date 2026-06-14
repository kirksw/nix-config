/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";

export const GENERATED_START = "<!-- lifeos:generated:start -->";
export const GENERATED_END = "<!-- lifeos:generated:end -->";

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

export function generatedBlock(content: string): string {
	const body = content.endsWith("\n") ? content.slice(0, -1) : content;
	return `${GENERATED_START}\n${body}\n${GENERATED_END}`;
}

export function replaceGeneratedBlock(
	existing: string,
	content: string,
): { text: string; changed: boolean; warning?: string } {
	const startCount = existing.split(GENERATED_START).length - 1;
	const endCount = existing.split(GENERATED_END).length - 1;
	if (startCount > 1 || endCount > 1) {
		return {
			text: existing,
			changed: false,
			warning: "duplicate generated markers; left file unchanged",
		};
	}

	const block = generatedBlock(content);
	const start = existing.indexOf(GENERATED_START);
	const end = existing.indexOf(GENERATED_END);
	if (start === -1 || end === -1 || end < start) {
		const separator = existing.endsWith("\n") ? "\n" : "\n\n";
		const text = `${existing}${separator}${block}\n`;
		return { text, changed: text !== existing };
	}

	const text = `${existing.slice(0, start)}${block}${existing.slice(end + GENERATED_END.length)}`;
	return { text, changed: text !== existing };
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
	if (next.changed) await fs.writeFile(file, next.text, "utf8");
	return { path: file, changed: next.changed, warning: next.warning };
}
