export type Scope = "personal" | "lunar";

// OKF workspaces use open vocabulary (for example initiative and exploration).
export type ThreadKind = string;

export type MetricKind =
	| "quantitative"
	| "qualitative"
	| "milestone"
	| "capability";

export const THREAD_KINDS: ThreadKind[] = [
	"idea",
	"research",
	"project",
	"product",
	"concept",
	"ops",
];

export interface LifeOsRecord {
	id: string;
	type: string;
	createdAt: string;
	updatedAt?: string;
}

export interface ThreadLinear {
	initiatives: string[];
	projects: string[];
}

export interface KnowledgeBaseReference {
	id: string;
	scope: string;
	note?: string;
}

export interface ThreadRecord extends LifeOsRecord {
	type: "thread";
	slug: string;
	title: string;
	kind: ThreadKind;
	status: string;
	stage: string;
	path: string;
	linear?: ThreadLinear;
	kbs?: KnowledgeBaseReference[];
	repos?: string[];
	salience?: number;
	impact?: number;
	confidence?: number;
	urgency?: number;
	effort?: number;
	manualOverride?: number;
}

export interface OutcomeRecord extends LifeOsRecord {
	type: "outcome";
	title: string;
	thread?: string;
	task?: string;
	goal: string;
	result?: string;
	state: "planned" | "in_progress" | "done" | "blocked" | "archived";
	closedAt?: string;
}

export type TaskStatus = "draft" | "specced" | "running" | "review" | "done" | "failed";

export interface TaskRecord extends LifeOsRecord {
	type: "task";
	title: string;
	thread: string;
	status: TaskStatus;
	path: string;
	packagePath: string;
	goal?: string;
	notes?: string;
}

export interface MetricRecord extends LifeOsRecord {
	type: "metric";
	name: string;
	kind: MetricKind;
	thread?: string;
	target?: string;
	current?: string;
}

export interface EdgeRecord extends LifeOsRecord {
	type: "edge";
	from: string;
	to: string;
	relation: string;
	weight?: number;
}

export interface BlockerRecord extends LifeOsRecord {
	type: "blocker";
	threadId?: string;
	text: string;
	status: "open" | "resolved";
}

export interface CandidateRecord extends LifeOsRecord {
	type: "candidate";
	text: string;
	source: "pi";
	status: "review" | "promoted" | "rejected";
	threadId?: string;
	reason?: string;
}

export interface DecisionRecord extends LifeOsRecord {
	type: "decision";
	text: string;
	source: "pi";
	threadId?: string;
}

export interface LifeOsData {
	threads: ThreadRecord[];
	tasks: TaskRecord[];
	outcomes: OutcomeRecord[];
	metrics: MetricRecord[];
	edges: EdgeRecord[];
	blockers: BlockerRecord[];
	candidates: CandidateRecord[];
	decisions: DecisionRecord[];
}
