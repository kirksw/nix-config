const RESERVED_LIFECYCLE_TAGS = /(^|[^A-Za-z0-9_-])@(open|claimed|ready-for-verification|resolved)(?=$|[^A-Za-z0-9_-])/i;

export type VerifyParams = {
	issue: string;
	command: string;
	exitStatus: number;
	evidence: string;
};

export function required(value: unknown, name: string): string {
	if (typeof value !== "string") throw new Error(`${name} must be a string.`);
	const text = value.trim();
	if (!text) throw new Error(`${name} must not be empty.`);
	return text;
}

export function userText(value: unknown, name: string): string {
	const text = required(value, name);
	if (RESERVED_LIFECYCLE_TAGS.test(text)) {
		throw new Error(`${name} must not contain reserved lifecycle tags (@open, @claimed, @ready-for-verification, or @resolved).`);
	}
	return text;
}

export function validateExitStatus(value: unknown): number {
	if (value === undefined || value === null) {
		throw new Error("exitStatus is required and must be a finite non-negative integer.");
	}
	if (typeof value !== "number" || !Number.isFinite(value) || !Number.isInteger(value) || value < 0) {
		throw new Error("exitStatus must be a finite non-negative integer.");
	}
	return value;
}

export function validateVerifyParams(params: {
	issue?: unknown;
	command?: unknown;
	exitStatus?: unknown;
	evidence?: unknown;
}): VerifyParams {
	return {
		issue: userText(params.issue, "issue"),
		command: userText(params.command, "command"),
		exitStatus: validateExitStatus(params.exitStatus),
		evidence: userText(params.evidence, "evidence"),
	};
}

export function parseVerifyPayload(raw: string): Record<string, unknown> {
	const text = raw.trim();
	if (!text) throw new Error("verify requires a JSON object with issue, command, exitStatus, and evidence.");

	let parsed: unknown;
	try {
		parsed = JSON.parse(text);
	} catch {
		throw new Error("verify expects a JSON object with issue, command, exitStatus, and evidence.");
	}
	if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
		throw new Error("verify expects a JSON object with issue, command, exitStatus, and evidence.");
	}
	return parsed as Record<string, unknown>;
}

export function parseLimit(value: unknown, defaultLimit: number, maxLimit: number): number {
	if (value === undefined || value === null) return defaultLimit;
	if (typeof value !== "number" || !Number.isFinite(value) || !Number.isInteger(value) || value < 1 || value > maxLimit) {
		throw new Error(`limit must be a positive integer no greater than ${maxLimit}.`);
	}
	return value;
}
