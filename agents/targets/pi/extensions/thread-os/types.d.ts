declare const process: {
	env: Record<string, string | undefined>;
	cwd(): string;
};

declare module "node:path" {
	export const sep: string;
	export function join(...parts: string[]): string;
	export function dirname(path: string): string;
	export function relative(from: string, to: string): string;
	export function resolve(...parts: string[]): string;
	export function basename(path: string, suffix?: string): string;
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
	export function readdir(path: string): Promise<string[]>;
	export function rename(oldPath: string, newPath: string): Promise<void>;
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

declare module "@mariozechner/pi-coding-agent" {
	export interface ExtensionAPI {
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
		signal?: AbortSignal;
		ui: {
			notify(
				message: string,
				level?: "info" | "warning" | "error" | "success",
			): void;
			setEditorText?(text: string): void;
			setStatus?(key: string, value?: string): void;
		};
	}
}
