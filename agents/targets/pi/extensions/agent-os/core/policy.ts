/// <reference path="../types.d.ts" />
import * as path from "node:path";
import type { AgentOsMode } from "./mode.js";

export type AgentOsRole = "OS" | "ThreadOS" | "FactoryOS";

export interface AgentOsPolicy {
	role: AgentOsRole;
	mode: AgentOsMode;
	workspacePath: string;
	threadPath?: string;
	workpackagePath?: string;
	canRead(file: string): boolean;
	canWrite(file: string): boolean;
	readDescription: string;
	writeDescription: string;
}

function inside(root: string, candidate: string, includeRoot = false): boolean {
	const relative = path.relative(path.resolve(root), path.resolve(candidate));
	return (includeRoot && relative === "") ||
		(relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative));
}

function validSegment(value: string | undefined): value is string {
	return Boolean(value && value !== "." && value !== ".." && !value.includes("/") && !value.includes("\\"));
}

function threadWriteAllowed(threadPath: string, file: string): boolean {
	if (!inside(threadPath, file, true)) return false;
	const relative = path.relative(path.resolve(threadPath), path.resolve(file));
	const parts = relative.split(path.sep).filter(Boolean);
	if (parts[0] !== "workpackages") return true;
	if (parts.length < 2) return false;
	return parts[2] === "package.md" || parts[2] === "input";
}

function factoryWriteAllowed(workpackagePath: string, file: string): boolean {
	if (!inside(workpackagePath, file, true)) return false;
	const relative = path.relative(path.resolve(workpackagePath), path.resolve(file));
	const [area] = relative.split(path.sep).filter(Boolean);
	return area === "runs" || area === "output";
}

export function policyFor(
	workspacePath: string,
	mode: AgentOsMode,
	thread?: string,
	workpackagePath?: string,
): AgentOsPolicy {
	if (mode === "OS") {
		return {
			role: "OS",
			mode,
			workspacePath,
			canRead: (file) => inside(workspacePath, file, true),
			canWrite: (file) => inside(workspacePath, file, true),
			readDescription: workspacePath,
			writeDescription: workspacePath,
		};
	}

	if (!validSegment(thread)) throw new Error(`${mode} requires a directory-safe thread binding`);
	const threadPath = path.resolve(workspacePath, "threads", thread);
	if (mode === "Thread") {
		return {
			role: "ThreadOS",
			mode,
			workspacePath,
			threadPath,
			canRead: (file) => inside(threadPath, file, true),
			canWrite: (file) => threadWriteAllowed(threadPath, file),
			readDescription: threadPath,
			writeDescription: `${threadPath} (ThreadOS-owned files only)`,
		};
	}

	if (!workpackagePath) throw new Error("FactoryOS requires a workpackage binding");
	const packagePath = path.resolve(workpackagePath);
	if (!inside(path.join(threadPath, "workpackages"), packagePath)) {
		throw new Error("FactoryOS workpackage must belong to the selected thread");
	}
	return {
		role: "FactoryOS",
		mode,
		workspacePath,
		threadPath,
		workpackagePath: packagePath,
		canRead: (file) => inside(packagePath, file, true),
		canWrite: (file) => factoryWriteAllowed(packagePath, file),
		readDescription: packagePath,
		writeDescription: `${packagePath}/runs and ${packagePath}/output`,
	};
}

export function assertPolicyRead(policy: AgentOsPolicy, file: string): void {
	if (!policy.canRead(file)) {
		throw new Error(`${policy.role} cannot read outside ${policy.readDescription}: ${file}`);
	}
}

export function assertPolicyWrite(policy: AgentOsPolicy, file: string): void {
	if (!policy.canWrite(file)) {
		throw new Error(`${policy.role} cannot write outside ${policy.writeDescription}: ${file}`);
	}
}

export function policyPrompt(policy: AgentOsPolicy): string {
	return [
		"## Agent OS access policy (enforced)",
		`- Role: ${policy.role}`,
		`- Read access: ${policy.readDescription}`,
		`- Write access: ${policy.writeDescription}`,
		"- Do not inspect, read, or write Agent OS workspace paths outside these boundaries.",
		"- If a requested operation is outside the boundary, stop and report it instead of bypassing the policy.",
	].join("\n");
}

export function shellMentionsProtectedWorkspace(
	policy: AgentOsPolicy,
	command: string,
): boolean {
	if (policy.role === "OS") return false;
	const normalized = command.replaceAll("\\", "/");
	const workspace = policy.workspacePath.replaceAll("\\", "/");
	return normalized.includes(workspace) || /(?:^|[\s/'\"])(?:\.\/)?workspace\//.test(normalized);
}
