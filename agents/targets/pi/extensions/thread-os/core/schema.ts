export type Scope = "personal" | "lunar";

export type ThreadKind =
	| "idea"
	| "research"
	| "project"
	| "product"
	| "concept"
	| "ops";

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

export interface ThreadRecord extends LifeOsRecord {
	type: "thread";
	slug: string;
	title: string;
	kind: ThreadKind;
	status: "active" | "blocked" | "paused" | "done" | "inbox";
	stage: string;
	path: string;
	salience?: number;
	impact?: number;
	confidence?: number;
	urgency?: number;
	effort?: number;
	manualOverride?: number;
}

export interface MetricRecord extends LifeOsRecord {
	type: "metric";
	name: string;
	kind: MetricKind;
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

export type StoreFile =
	| "threads"
	| "metrics"
	| "sessions"
	| "decisions"
	| "blockers"
	| "artifacts"
	| "concepts"
	| "edges"
	| "candidates"
	| "evolution_proposals";

export const STORE_FILES: StoreFile[] = [
	"threads",
	"metrics",
	"sessions",
	"decisions",
	"blockers",
	"artifacts",
	"concepts",
	"edges",
	"candidates",
	"evolution_proposals",
];

export interface LifeOsData {
	threads: ThreadRecord[];
	metrics: MetricRecord[];
	edges: EdgeRecord[];
	blockers: BlockerRecord[];
	candidates: CandidateRecord[];
	decisions: DecisionRecord[];
}
