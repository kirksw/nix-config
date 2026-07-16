/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";

export interface PromotionProposal {
	files: string[];
	promoted: boolean;
}

async function filesUnder(root: string): Promise<string[]> {
	const rootStat = await fs.lstat(root).catch(() => undefined);
	if (!rootStat) return [];
	if (rootStat.isSymbolicLink()) throw new Error(`promotion source cannot contain symlinks: ${root}`);
	if (!rootStat.isDirectory()) throw new Error(`promotion source is not a directory: ${root}`);
	const result: string[] = [];
	for (const name of await fs.readdir(root)) {
		const file = path.join(root, name);
		const stat = await fs.lstat(file);
		if (stat.isSymbolicLink()) throw new Error(`promotion source cannot contain symlinks: ${file}`);
		if (stat.isDirectory()) result.push(...(await filesUnder(file)));
		else if (stat.isFile()) result.push(file);
	}
	return result;
}

function validSegment(value: string): boolean {
	return Boolean(value && value !== "." && value !== ".." && !value.includes("/") && !value.includes("\\"));
}

function inside(root: string, candidate: string, includeRoot = false): boolean {
	const relative = path.relative(path.resolve(root), path.resolve(candidate));
	return (includeRoot && relative === "") ||
		(relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative));
}

/** Copy Factory output only after the caller has shown this proposal and obtained confirmation. */
export async function promoteOutputToWiki(workspacePath: string, thread: string, workpackage: string, confirmed: boolean): Promise<PromotionProposal> {
	if (!validSegment(thread) || !validSegment(workpackage)) throw new Error("promotion requires directory-safe thread and workpackage identifiers");
	const workspaceRoot = path.resolve(workspacePath);
	const outputRoot = path.resolve(workspaceRoot, "threads", thread, "workpackages", workpackage, "output");
	const wikiRoot = path.resolve(workspaceRoot, "wiki");
	if (!inside(workspaceRoot, outputRoot) || !inside(workspaceRoot, wikiRoot)) throw new Error("invalid promotion path");
	const files = (await filesUnder(outputRoot)).map((file) => path.relative(outputRoot, file)).sort();
	if (!confirmed) return { files, promoted: false };
	for (const relative of files) {
		const source = path.resolve(outputRoot, relative);
		const target = path.resolve(wikiRoot, relative);
		if (!inside(outputRoot, source) || !inside(wikiRoot, target)) throw new Error("invalid promotion path");
		const targetStat = await fs.lstat(target).catch(() => undefined);
		if (targetStat?.isSymbolicLink()) throw new Error(`promotion target cannot be a symlink: ${target}`);
		await fs.mkdir(path.dirname(target), { recursive: true });
		await fs.copyFile(source, target);
	}
	return { files, promoted: true };
}
