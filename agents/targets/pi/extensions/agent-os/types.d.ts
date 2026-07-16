declare const process: {
	env: Record<string, string | undefined>;
	pid: number;
	cwd(): string;
};

declare module "node:path" {
	export const sep: string;
	export function join(...parts: string[]): string;
	export function dirname(path: string): string;
	export function relative(from: string, to: string): string;
	export function resolve(...parts: string[]): string;
	export function basename(path: string, suffix?: string): string;
	export function isAbsolute(path: string): boolean;
}

declare module "node:fs/promises" {
	export function mkdir(
		path: string,
		options?: { recursive?: boolean },
	): Promise<void>;
	export function readFile(path: string, encoding: "utf8"): Promise<string>;
	export function writeFile(
		path: string,
		data: string,
		encoding?: "utf8",
	): Promise<void>;
	export function appendFile(
		path: string,
		data: string,
		encoding?: "utf8",
	): Promise<void>;
	export function stat(
		path: string,
	): Promise<{ isDirectory(): boolean; isFile(): boolean }>;
	export function realpath(path: string): Promise<string>;
	export function readdir(path: string): Promise<string[]>;
	export function rename(oldPath: string, newPath: string): Promise<void>;
	export function rm(path: string, options?: { recursive?: boolean; force?: boolean }): Promise<void>;
}

declare module "node:child_process" {
	export function execFile(
		file: string,
		args?: readonly string[],
		options?: Record<string, unknown>,
		callback?: (...args: unknown[]) => void,
	): unknown;
}

declare module "node:util" {
	export function promisify<T extends (...args: never[]) => unknown>(
		fn: T,
	): (...args: Parameters<T>) => Promise<unknown>;
}

declare module "@earendil-works/pi-tui" {
	export function truncateToWidth(text: string, width: number, ellipsis?: string): string;
	export function visibleWidth(text: string): number;
}

declare module "@earendil-works/pi-coding-agent" {
	export interface ExtensionAPI {
		on(
			event:
				| "session_start"
				| "turn_end"
				| "session_switch"
				| "session_shutdown"
				| "before_agent_start"
				| "tool_call",
			handler: (event: any, ctx: ExtensionContext) => unknown | Promise<unknown>,
		): void;
		appendEntry(type: string, data?: unknown): void;
		sendMessage(message: {
			customType: string;
			content: string;
			display?: boolean;
			details?: unknown;
		}): void;
		exec(
			command: string,
			args?: readonly string[],
			options?: { signal?: AbortSignal; timeout?: number },
		): Promise<{ stdout: string; stderr: string; code: number; killed?: boolean }>;
		registerMessageRenderer(
			customType: string,
			renderer: (message: { content: string }, options: { expanded: boolean }, theme: unknown) => unknown,
		): void;
		registerCommand(
			name: string,
			spec: {
				description: string;
				handler: (
					args: string,
					ctx: ExtensionContext,
				) => unknown | Promise<unknown>;
			},
		): void;
	}

	export interface ExtensionContext {
		cwd: string;
		mode?: string;
		hasUI?: boolean;
		sessionManager: {
			getEntries(): Array<{
				type: string;
				customType?: string;
				data?: unknown;
			}>;
		};
		newSession?(options?: {
			setup?: (sessionManager: {
				appendCustomEntry(customType: string, data?: unknown): string;
				appendSessionInfo(name: string): string;
			}) => void | Promise<void>;
			withSession?: (ctx: ExtensionContext) => void | Promise<void>;
		}): Promise<{ cancelled: boolean }>;
		signal?: AbortSignal;
		ui: {
			notify(
				message: string,
				level?: "info" | "warning" | "error" | "success",
			): void;
			setEditorText?(text: string): void;
			setStatus?(key: string, value?: string): void;
			setWidget?(
				key: string,
				content?:
					| string[]
					| ((
						tui: unknown,
						theme: { fg(color: string, text: string): string },
					) => { render(width: number): string[]; invalidate?(): void }),
				options?: { placement?: "aboveEditor" | "belowEditor" },
			): void;
			getEditorText?(): string;
			onTerminalInput?(handler: (data: string) => void): () => void;
			custom?<T>(
				factory: (
					tui: { requestRender(): void },
					theme: {
						fg(color: string, text: string): string;
						bold(text: string): string;
					},
					keybindings: unknown,
					done: (result: T) => void,
				) => {
					handleInput(data: string): void;
					render(width: number): string[];
					invalidate?(): void;
				},
			): Promise<T>;
			theme?: {
				fg(color: string, text: string): string;
				bold(text: string): string;
			};
			addAutocompleteProvider?(factory: (current: {
				getSuggestions(
					lines: string[],
					cursorLine: number,
					cursorCol: number,
					options: unknown,
				): unknown;
				applyCompletion(
					lines: string[],
					cursorLine: number,
					cursorCol: number,
					item: unknown,
					prefix: string,
				): unknown;
				shouldTriggerFileCompletion?(
					lines: string[],
					cursorLine: number,
					cursorCol: number,
				): boolean;
			}) => unknown): void;
		};
	}
}
