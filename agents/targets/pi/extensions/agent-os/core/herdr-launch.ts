export type HerdrWorkspaceEnvelope = {
	result?: {
		root_pane?: { pane_id?: string };
		workspace?: { workspace_id?: string };
	};
};

function shellQuote(value: string): string {
	return `'${value.replaceAll("'", "'\\''")}'`;
}

export function herdrCreateArgs(project: string, label: string): string[] {
	return ["workspace", "create", "--cwd", project, "--label", label, "--focus"];
}

export function herdrRunArgs(paneId: string, project: string, thread: string): string[] {
	return [
		"pane",
		"run",
		paneId,
		`agent-os launch --thread ${shellQuote(thread)} --project ${shellQuote(project)}`,
	];
}

export function herdrFactoryRunArgs(paneId: string, project: string, thread: string, task: string): string[] {
	return [
		"pane",
		"run",
		paneId,
		`agent-os launch --thread ${shellQuote(thread)} --task ${shellQuote(task)} --project ${shellQuote(project)}`,
	];
}

export function rootPaneId(stdout: string): string {
	let envelope: HerdrWorkspaceEnvelope;
	try {
		envelope = JSON.parse(stdout) as HerdrWorkspaceEnvelope;
	} catch {
		throw new Error("Herdr returned invalid workspace JSON");
	}
	const paneId = envelope.result?.root_pane?.pane_id;
	if (!paneId) throw new Error("Herdr workspace has no root pane");
	return paneId;
}
