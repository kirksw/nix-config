import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const ONE_HOUR_TTL = "1h";

export function applyOneHourTtl(value: unknown): void {
	if (Array.isArray(value)) {
		for (const item of value) {
			applyOneHourTtl(item);
		}
		return;
	}

	if (!value || typeof value !== "object") {
		return;
	}

	const object = value as Record<string, unknown>;
	const cacheControl = object.cache_control;

	if (cacheControl && typeof cacheControl === "object" && !Array.isArray(cacheControl)) {
		const control = cacheControl as Record<string, unknown>;
		if (control.type === "ephemeral") {
			control.ttl = ONE_HOUR_TTL;
		}
	}

	for (const child of Object.values(object)) {
		applyOneHourTtl(child);
	}
}

export default function anthropicLongCache(pi: ExtensionAPI): void {
	pi.on("before_provider_request", (event, ctx) => {
		if (ctx.model?.provider !== "anthropic" || ctx.model.api !== "anthropic-messages") {
			return;
		}

		applyOneHourTtl(event.payload);
		return event.payload;
	});
}
