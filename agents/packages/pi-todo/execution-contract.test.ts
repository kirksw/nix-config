import { createMockCtx, createMockPi } from "./test-fixtures.js";
import { beforeEach, describe, expect, it, vi } from "vitest";
import registerTodo, {
	AUTO_CONTINUATION_CUSTOM_TYPE,
	buildLiveTaskBlock,
	LIVE_TASK_CUSTOM_TYPE,
	STATIC_EXECUTION_POLICY,
} from "./index.js";
import { getActiveRenderSession, replaceState, setActiveRenderSession } from "./state/store.js";
import type { Task } from "./tool/types.js";

const sessionId = "foreground";

function task(id: number, subject: string, status: Task["status"], blockedBy?: number[]): Task {
	return { id, subject, status, ...(blockedBy ? { blockedBy } : {}) };
}

function setup(tasks: Task[] = []) {
	const { pi, captured } = createMockPi();
	setActiveRenderSession(sessionId);
	replaceState(sessionId, { tasks, nextId: tasks.length + 1 });
	registerTodo(pi);
	const ctx = createMockCtx({ sessionId, hasUI: true });
	ctx.isIdle = vi.fn(() => true);
	ctx.hasPendingMessages = vi.fn(() => false);
	return { pi, captured, ctx };
}

function handler(captured: ReturnType<typeof createMockPi>["captured"], name: string) {
	const value = captured.events.get(name)?.[0];
	if (!value) throw new Error(`${name} handler missing`);
	return value as (...args: any[]) => any;
}

beforeEach(() => setActiveRenderSession(sessionId));

describe("todo execution contract", () => {
	it("injects the immutable policy through before_agent_start", async () => {
		const { captured, ctx } = setup();
		const result = await handler(captured, "before_agent_start")(
			{
				systemPrompt: "base",
			},
			ctx,
		);
		expect(result.systemPrompt).toContain(STATIC_EXECUTION_POLICY);
	});

	it("injects one persistent live-state snapshot per external turn", async () => {
		const tasks = [
			task(1, "done", "completed"),
			task(2, "blocked", "pending", [3]),
			task(3, "next", "in_progress", [1]),
		];
		const { captured, ctx } = setup(tasks);
		const input = handler(captured, "input");
		const beforeStart = handler(captured, "before_agent_start");

		await input({ source: "interactive" }, ctx);
		const first = await beforeStart({ systemPrompt: "base" }, ctx);
		const continuation = await beforeStart({ systemPrompt: "base" }, ctx);

		expect(first.message.customType).toBe(LIVE_TASK_CUSTOM_TYPE);
		expect(first.message.content).toContain('"subject":"blocked"');
		expect(first.message.content).toContain('"nextActionableTask":{"id":3');
		expect(continuation.message).toBeUndefined();
		expect(buildLiveTaskBlock({ tasks: [task(1, "x", "completed")], nextId: 2 })).toBeUndefined();
	});

	it("keeps only the newest live snapshot in its chronological position", async () => {
		const { captured } = setup();
		const context = handler(captured, "context");
		const oldSnapshot = { role: "custom", customType: LIVE_TASK_CUSTOM_TYPE, content: "old", display: false };
		const currentSnapshot = {
			role: "custom",
			customType: LIVE_TASK_CUSTOM_TYPE,
			content: "current",
			display: false,
		};
		const user = { role: "user", content: "keep" };
		const assistant = { role: "assistant", content: "also keep" };
		const result = await context({ messages: [oldSnapshot, user, currentSnapshot, assistant] });
		expect(result.messages).toEqual([user, currentSnapshot, assistant]);
	});

	it("injects an empty snapshot to supersede historical open tasks", async () => {
		const { captured, ctx } = setup();
		await handler(captured, "input")({ source: "rpc" }, ctx);
		const result = await handler(captured, "before_agent_start")({ systemPrompt: "base" }, ctx);
		expect(result.message.content).toContain('"tasks":[]');
		expect(result.message.content).toContain('"nextActionableTask":null');
	});

	it("continues once per external user turn and sets the guard before sending", async () => {
		const { pi, captured, ctx } = setup([task(1, "work", "pending")]);
		const input = handler(captured, "input");
		const settled = handler(captured, "agent_settled");

		await input({ source: "interactive" }, ctx);
		await settled({}, ctx);
		await settled({}, ctx);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(1);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls[0][1]).toEqual({
			deliverAs: "followUp",
			triggerTurn: true,
		});
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls[0][0].customType).toBe(
			AUTO_CONTINUATION_CUSTOM_TYPE,
		);
	});

	it("does not re-arm from extension input, including its generated continuation", async () => {
		const { pi, captured, ctx } = setup([task(1, "work", "pending")]);
		const input = handler(captured, "input");
		const settled = handler(captured, "agent_settled");

		await input({ source: "interactive" }, ctx);
		await settled({}, ctx);
		await input({ source: "extension" }, ctx);
		await settled({}, ctx);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(1);
	});

	it("does not continue when the only visible task is deleted", async () => {
		const { pi, captured, ctx } = setup([task(1, "deleted", "deleted")]);
		await handler(captured, "input")({ source: "rpc" }, ctx);
		await handler(captured, "agent_settled")({}, ctx);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(0);
	});

	it("does not let an aborted child agent_end cancel the foreground guard", async () => {
		const { pi, captured, ctx } = setup([task(1, "work", "pending")]);
		const child = createMockCtx({ sessionId: "child" });
		child.signal = { aborted: true } as AbortSignal;

		await handler(captured, "input")({ source: "interactive" }, ctx);
		await handler(captured, "agent_end")({}, child);
		await handler(captured, "agent_settled")({}, ctx);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(1);
	});

	it("suppresses continuation when the foreground signal is aborted", async () => {
		const { pi, captured, ctx } = setup([task(1, "work", "pending")]);
		ctx.signal = { aborted: true } as AbortSignal;

		await handler(captured, "input")({ source: "interactive" }, ctx);
		await handler(captured, "agent_end")({}, ctx);
		await handler(captured, "agent_settled")({}, ctx);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(0);
	});

	it("keeps a concrete child shutdown from mutating the foreground guard", async () => {
		const { pi, captured, ctx } = setup([task(1, "work", "pending")]);
		const child = createMockCtx({ sessionId: "child" });

		await handler(captured, "input")({ source: "interactive" }, ctx);
		await handler(captured, "session_shutdown")({}, child);
		expect(getActiveRenderSession()).toBe(sessionId);
		await handler(captured, "agent_settled")({}, ctx);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(1);
	});

	it("keeps a stale shutdown from mutating the foreground guard", async () => {
		const { pi, captured, ctx } = setup([task(1, "work", "pending")]);
		const stale = {
			hasUI: false,
			get sessionManager(): never {
				throw new Error("This extension ctx is stale after session replacement or reload.");
			},
		} as never;

		await handler(captured, "input")({ source: "interactive" }, ctx);
		await handler(captured, "session_shutdown")({}, stale);
		expect(getActiveRenderSession()).toBe(sessionId);
		await handler(captured, "agent_settled")({}, ctx);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(1);
	});

	it("starts a replacement session closed and only continues after new external input", async () => {
		const { pi, captured, ctx } = setup([task(1, "work", "pending")]);
		const replacement = createMockCtx({ sessionId: "replacement", hasUI: true });
		const start = handler(captured, "session_start");
		const shutdown = handler(captured, "session_shutdown");

		await handler(captured, "input")({ source: "interactive" }, ctx);
		await shutdown({}, ctx);
		await start({}, replacement);
		await handler(captured, "agent_settled")({}, replacement);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(0);

		replaceState("replacement", { tasks: [task(2, "new work", "pending")], nextId: 3 });
		await handler(captured, "input")({ source: "interactive" }, replacement);
		await handler(captured, "agent_settled")({}, replacement);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(1);
	});

	it("waits for an idle context with no queued messages", async () => {
		const { pi, captured, ctx } = setup([task(1, "work", "pending")]);
		await handler(captured, "input")({ source: "interactive" }, ctx);
		ctx.isIdle.mockReturnValue(false);
		await handler(captured, "agent_settled")({}, ctx);
		ctx.isIdle.mockReturnValue(true);
		ctx.hasPendingMessages.mockReturnValue(true);
		await handler(captured, "agent_settled")({}, ctx);
		expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(0);
	});

	it("does not continue completed or dependency-blocked work", async () => {
		for (const tasks of [
			[task(1, "done", "completed")],
			[task(1, "blocked", "pending", [2]), task(2, "blocked blocker", "in_progress", [3])],
		]) {
			const { pi, captured, ctx } = setup(tasks);
			await handler(captured, "input")({ source: "rpc" }, ctx);
			await handler(captured, "agent_settled")({}, ctx);
			expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(0);
			await handler(captured, "session_shutdown")({}, ctx);
			await handler(captured, "agent_settled")({}, ctx);
			expect((pi.sendMessage as ReturnType<typeof vi.fn>).mock.calls).toHaveLength(0);
		}
	});
});

void AUTO_CONTINUATION_CUSTOM_TYPE;
