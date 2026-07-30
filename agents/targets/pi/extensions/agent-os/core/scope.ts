/// <reference path="../types.d.ts" />
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Scope } from "./schema.ts";

export interface ScopeResolution {
	scope: Scope | null;
	reason: string;
}

function hasToken(value: string | undefined, token: string): boolean {
	return (value ?? "")
		.toLowerCase()
		.split(/[^a-z0-9]+/)
		.includes(token);
}

export function resolveScope(ctx?: ExtensionContext): ScopeResolution {
	const explicit = process.env.AGENT_OS_SCOPE?.toLowerCase();
	if (explicit === "personal" || explicit === "lunar") {
		return { scope: explicit, reason: "AGENT_OS_SCOPE" };
	}

	const envPairs: Array<[string, string | undefined]> = [
		["NAX_BASE", process.env.NAX_BASE],
		["NAX_PROFILE", process.env.NAX_PROFILE],
		["PI_CODING_AGENT_DIR", process.env.PI_CODING_AGENT_DIR],
	];

	for (const [name, value] of envPairs) {
		const isFactory = hasToken(value, "factory");
		if (
			hasToken(value, "personal") ||
			(isFactory && hasToken(value, "home"))
		)
			return { scope: "personal", reason: name };
		if (hasToken(value, "lunar") || hasToken(value, "work"))
			return { scope: "lunar", reason: name };
	}

	void ctx;
	return { scope: null, reason: "unknown profile/base" };
}
