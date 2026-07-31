// Narrow copy of the @juicesharp/rpiv-test-utils fixtures used by this package.
// Baseline: rpiv-mono v2.2.0 (8567ce713a7670da7a5456666a3be0adf80d2820).

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { Api, Message, Model, ToolResultMessage, UserMessage } from "@earendil-works/pi-ai";
import type {
	ExtensionAPI,
	ExtensionContext,
	ExtensionUIContext,
	RegisteredCommand,
	SessionEntry,
	Theme,
	ToolDefinition,
	ToolInfo,
} from "@earendil-works/pi-coding-agent";
import { vi } from "vitest";

export interface CapturedShortcut {
	description?: string;
	handler: (ctx: unknown) => Promise<void> | void;
}

export interface CapturedPi {
	tools: Map<string, ToolDefinition>;
	commands: Map<string, Omit<RegisteredCommand, "name" | "sourceInfo">>;
	shortcuts: Map<string, CapturedShortcut>;
	flags: Map<string, unknown>;
	events: Map<string, Array<(...args: unknown[]) => unknown>>;
	eventsEmitted: Map<string, unknown[]>;
	activeTools: string[];
	allTools: ToolInfo[];
}

export interface MockPi {
	pi: ExtensionAPI;
	captured: CapturedPi;
}

export function createMockPi(options: Partial<ExtensionAPI> = {}): MockPi {
	const captured: CapturedPi = {
		tools: new Map(),
		commands: new Map(),
		shortcuts: new Map(),
		flags: new Map(),
		events: new Map(),
		eventsEmitted: new Map(),
		activeTools: [],
		allTools: [],
	};

	const pi = {
		registerTool: vi.fn((tool: ToolDefinition) => {
			captured.tools.set(tool.name, tool);
			if (!captured.activeTools.includes(tool.name)) captured.activeTools.push(tool.name);
		}),
		registerCommand: vi.fn((name: string, cmd: Omit<RegisteredCommand, "name" | "sourceInfo">) => {
			captured.commands.set(name, cmd);
		}),
		registerShortcut: vi.fn((shortcut: string, opts: CapturedShortcut) => {
			captured.shortcuts.set(shortcut, opts);
		}),
		registerFlag: vi.fn((name: string, value: unknown) => {
			captured.flags.set(name, value);
		}),
		getFlag: vi.fn((name: string) => captured.flags.get(name)),
		on: vi.fn((event: string, handler: (...args: unknown[]) => unknown) => {
			const list = captured.events.get(event) ?? [];
			list.push(handler);
			captured.events.set(event, list);
		}),
		sendMessage: vi.fn(async () => {}),
		sendUserMessage: vi.fn(() => {}),
		exec: vi.fn(async () => ({ stdout: "", stderr: "", code: 0, killed: false })),
		getActiveTools: vi.fn(() => [...captured.activeTools]),
		setActiveTools: vi.fn((names: string[]) => {
			captured.activeTools = [...names];
		}),
		getAllTools: vi.fn(() => [...captured.allTools]),
		getThinkingLevel: vi.fn(() => "medium"),
		events: {
			emit: vi.fn((channel: string, data: unknown) => {
				const list = captured.eventsEmitted.get(channel) ?? [];
				list.push(data);
				captured.eventsEmitted.set(channel, list);
			}),
			on: vi.fn(() => () => {}),
		},
		getCommands: vi.fn(() => []),
		...options,
	} as unknown as ExtensionAPI;

	return { pi, captured };
}

export interface MockUI {
	notify: ReturnType<typeof vi.fn>;
	confirm: ReturnType<typeof vi.fn>;
	input: ReturnType<typeof vi.fn>;
	select: ReturnType<typeof vi.fn>;
	setWidget: ReturnType<typeof vi.fn>;
	setStatus: ReturnType<typeof vi.fn>;
	setWorkingMessage: ReturnType<typeof vi.fn>;
	setHiddenThinkingLabel: ReturnType<typeof vi.fn>;
	onTerminalInput: ReturnType<typeof vi.fn>;
	pasteToEditor: ReturnType<typeof vi.fn>;
	setEditorComponent: ReturnType<typeof vi.fn>;
	theme?: Theme | MockTheme;
}

export interface MockTheme {
	fg: (_color: string, text: string) => string;
	bg: (_color: string, text: string) => string;
	bold: (text: string) => string;
	strikethrough: (text: string) => string;
}

export function createMockUI(
	overrides: Partial<Omit<ExtensionUIContext, "theme">> & { theme?: Theme | MockTheme } = {},
): MockUI {
	return {
		notify: vi.fn(),
		confirm: vi.fn(async () => true),
		input: vi.fn(async () => ""),
		select: vi.fn(async () => undefined),
		setWidget: vi.fn(),
		setStatus: vi.fn(),
		setWorkingMessage: vi.fn(),
		setHiddenThinkingLabel: vi.fn(),
		onTerminalInput: vi.fn(() => () => {}),
		pasteToEditor: vi.fn(),
		setEditorComponent: vi.fn(),
		...overrides,
	} as unknown as MockUI;
}

function createMockSessionManager(branch: SessionEntry[] = [], sessionId = "test-session") {
	return {
		getBranch: vi.fn(() => branch),
		getEntries: vi.fn(() => branch),
		getLeafId: vi.fn(() => (branch.length ? branch[branch.length - 1].id : null)),
		getSessionFile: vi.fn(() => "/tmp/test-session.jsonl"),
		getSessionId: vi.fn(() => sessionId),
	};
}

export interface MockCtxOptions {
	hasUI?: boolean;
	cwd?: string;
	model?: Model<Api>;
	branch?: SessionEntry[];
	models?: Model<Api>[];
	ui?: Partial<ExtensionUIContext>;
	sessionId?: string;
}

function createMockModelRegistry(models: Model<Api>[] = []) {
	return {
		find: vi.fn((provider: string, id: string) => models.find((m) => m.provider === provider && m.id === id)),
		getAvailable: vi.fn(() => [...models]),
		getApiKeyAndHeaders: vi.fn(async () => ({ ok: true, apiKey: "test-key", headers: {} })),
	};
}

export type MockContext = ExtensionContext;

export function createMockCtx(opts: MockCtxOptions = {}): MockContext {
	return {
		hasUI: opts.hasUI ?? false,
		cwd: opts.cwd ?? "/tmp/test-cwd",
		model: opts.model,
		ui: createMockUI(opts.ui),
		sessionManager: createMockSessionManager(opts.branch ?? [], opts.sessionId),
		modelRegistry: createMockModelRegistry(opts.models ?? []),
		isIdle: vi.fn(() => true),
		hasPendingMessages: vi.fn(() => false),
		signal: undefined,
	} as unknown as MockContext;
}

export function makeUserMessage(text: string): UserMessage {
	return {
		role: "user",
		content: [{ type: "text", text }],
		timestamp: Date.now(),
	};
}

function makeMessageEntry(message: Message): SessionEntry {
	return { type: "message", message } as unknown as SessionEntry;
}

export function buildSessionEntries(messages: Message[]): SessionEntry[] {
	return messages.map(makeMessageEntry);
}

function makeToolResult(input: {
	toolName: string;
	text?: string;
	details?: unknown;
}): ToolResultMessage {
	return {
		role: "toolResult",
		toolCallId: `call-${input.toolName}-${Date.now()}`,
		toolName: input.toolName,
		content: input.text ? [{ type: "text", text: input.text }] : [],
		details: input.details,
		isError: false,
		timestamp: Date.now(),
	} as unknown as ToolResultMessage;
}

export function makeTodoToolResult(details: unknown, text = "ok"): ToolResultMessage {
	return makeToolResult({ toolName: "todo", text, details });
}

export function makeTheme(overrides: Partial<MockTheme> = {}): MockTheme {
	return {
		fg: (_color, text) => text,
		bg: (_color, text) => text,
		bold: (text) => text,
		strikethrough: (text) => text,
		...overrides,
	};
}

const SKIP_DIRS = new Set(["node_modules", "docs"]);
const SKIP_FILES = new Set(["test-fixtures.ts"]);

export interface ShipManifestResult {
	declared: readonly string[];
	onDisk: readonly string[];
	missing: readonly string[];
	stale: readonly string[];
}

export function verifyShipManifest(packageDirOrUrl: string): ShipManifestResult {
	const packageDir = packageDirOrUrl.startsWith("file:") ? dirname(fileURLToPath(packageDirOrUrl)) : packageDirOrUrl;
	const pkgRaw = readFileSync(resolve(packageDir, "package.json"), "utf8");
	const pkg = JSON.parse(pkgRaw) as { files?: string[] };
	const declared = pkg.files ?? [];
	const exactFiles = new Set<string>();
	const dirPrefixes: string[] = [];
	for (const entry of declared) {
		if (entry.startsWith("!")) continue;
		if (entry.endsWith("/")) dirPrefixes.push(entry);
		else if (isDirOnDisk(packageDir, entry)) dirPrefixes.push(`${entry}/`);
		else exactFiles.add(entry);
	}

	const onDisk = walkProductionTs(packageDir, packageDir);
	const missing = onDisk.filter((f) => !isCovered(f, exactFiles, dirPrefixes));
	const stale = declared.filter((entry) => !entry.startsWith("!") && !existsSync(resolve(packageDir, entry)));

	return { declared, onDisk, missing, stale };
}

function isDirOnDisk(packageDir: string, entry: string): boolean {
	try {
		return statSync(resolve(packageDir, entry)).isDirectory();
	} catch {
		return false;
	}
}

function isCovered(file: string, exactFiles: Set<string>, dirPrefixes: readonly string[]): boolean {
	if (exactFiles.has(file)) return true;
	return dirPrefixes.some((prefix) => file.startsWith(prefix));
}

function walkProductionTs(root: string, dir: string): string[] {
	const out: string[] = [];
	for (const entry of readdirSync(dir, { withFileTypes: true })) {
		if (entry.name.startsWith(".")) continue;
		if (entry.isDirectory() && SKIP_DIRS.has(entry.name)) continue;
		const abs = resolve(dir, entry.name);
		if (entry.isDirectory()) {
			out.push(...walkProductionTs(root, abs));
			continue;
		}
		if (!entry.isFile() || !entry.name.endsWith(".ts")) continue;
		if (entry.name.endsWith(".test.ts") || SKIP_FILES.has(entry.name)) continue;
		out.push(relative(root, abs));
	}
	return out;
}
