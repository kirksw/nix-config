/**
 * Shared types for the PR reviewer extension.
 */

export type Severity = "critical" | "high" | "medium" | "low" | "info";

export const SEVERITY_RANK: Record<Severity, number> = {
  critical: 0,
  high: 1,
  medium: 2,
  low: 3,
  info: 4,
};

export type ReviewerId = "general" | "security" | "code-quality" | "ci" | "performance";

export type Tier = "low" | "medium" | "high";

export interface PRMeta {
  number: number;
  title: string;
  author: string;
  headRefName: string;
  baseRefName: string;
  isDraft: boolean;
  additions: number;
  deletions: number;
  changedFiles: number;
  body: string;
  url: string;
}

export interface PRListItem {
  number: number;
  title: string;
  author: string;
  headRefName: string;
  isDraft: boolean;
  additions: number;
  deletions: number;
  changedFiles: number;
}

/** A request from a reviewer for more context than the diff provides. */
export interface InfoRequest {
  type: "read" | "grep";
  /** For read: file path. For grep: optional path/dir to scope the search. */
  path?: string;
  /** For read: "start-end" line range (1-indexed), optional. */
  lines?: string;
  /** For grep: the pattern to search for. */
  pattern?: string;
}

export interface Issue {
  id?: string;
  severity: Severity;
  /** Reviewer category, e.g. "security". Populated by the orchestrator. */
  category: string;
  title: string;
  file?: string;
  line?: number | string;
  rationale: string;
  recommendation: string;
  /** Reviewer ids that flagged this (filled after dedup). */
  reporters?: string[];
}

export interface ReviewerOutput {
  issues: Issue[];
  requests?: InfoRequest[];
}

export interface SummaryOutput {
  summary: string;
  majorBehaviorChange: boolean;
  riskNotes?: string;
}

export interface ReviewerResult {
  reviewer: ReviewerId;
  issues: Issue[];
  ok: boolean;
  error?: string;
}
