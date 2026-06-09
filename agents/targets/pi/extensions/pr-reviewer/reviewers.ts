/**
 * Adversarial reviewer roster, complexity tiering, and prompt construction.
 *
 * Each reviewer is an isolated `pi` subprocess fed ONLY the diff. Reviewers
 * are adversarial: their job is to find problems, not to praise. They emit a
 * strict JSON object and may ask the orchestrator for more context.
 */

import type { PRMeta, ReviewerId, Tier } from "./types.js";

interface ReviewerSpec {
  id: ReviewerId;
  title: string;
  /** Role-specific adversarial system prompt (focus area). */
  focus: string;
}

const REVIEWERS: Record<ReviewerId, ReviewerSpec> = {
  general: {
    id: "general",
    title: "General Reviewer",
    focus: [
      "You are an adversarial general-purpose code reviewer.",
      "Hunt for correctness bugs, broken edge cases, off-by-one errors, nil/null handling,",
      "error-handling gaps, missing or wrong tests, unclear logic, and regressions in behaviour.",
      "Assume the author made a mistake somewhere and find it.",
    ].join(" "),
  },
  security: {
    id: "security",
    title: "Security Reviewer",
    focus: [
      "You are an adversarial application-security reviewer.",
      "Hunt for injection, broken authn/authz, privilege escalation, RBAC misconfiguration,",
      "secret leakage, unsafe deserialization, SSRF, path traversal, missing input validation,",
      "insecure defaults, and risky dependency or supply-chain changes.",
      "Treat every new permission grant or policy change as suspect until proven safe.",
    ].join(" "),
  },
  "code-quality": {
    id: "code-quality",
    title: "Code Quality Reviewer",
    focus: [
      "You are an adversarial code-quality and maintainability reviewer.",
      "Hunt for duplication, poor naming, dead code, leaky abstractions, inconsistent error handling,",
      "missing documentation on exported APIs, non-idiomatic patterns, and high-complexity functions.",
      "Flag anything that will make the code harder to maintain.",
    ].join(" "),
  },
  ci: {
    id: "ci",
    title: "CI / Build Reviewer",
    focus: [
      "You are an adversarial CI and build-system reviewer doing STATIC analysis only (do not run anything).",
      "Reason about whether this change breaks the build, tests, linting, or release pipeline.",
      "Hunt for changes that need but lack matching test/workflow/Makefile updates, version mismatches,",
      "broken CI YAML, removed-but-referenced targets, and changes that would fail in CI but pass locally.",
    ].join(" "),
  },
  performance: {
    id: "performance",
    title: "Performance Reviewer",
    focus: [
      "You are an adversarial performance reviewer.",
      "Hunt for N+1 queries, unbounded loops/allocations on hot paths, needless copies, blocking I/O in",
      "concurrent code, missing pagination/limits, lock contention, and accidental O(n^2) behaviour.",
    ].join(" "),
  },
};

const OUTPUT_CONTRACT = `
Respond with EXACTLY ONE fenced JSON block and nothing else. Schema:
\`\`\`json
{
  "issues": [
    {
      "severity": "critical|high|medium|low|info",
      "title": "short imperative summary",
      "file": "path/to/file (optional)",
      "line": 123,
      "rationale": "why this is a problem",
      "recommendation": "concrete fix"
    }
  ],
  "requests": [
    { "type": "read", "path": "path/to/file.go", "lines": "120-160" },
    { "type": "grep", "pattern": "FunctionName", "path": "optional/dir" }
  ]
}
\`\`\`
Rules:
- Only report REAL problems you can justify from the diff (or requested context). Do not invent issues.
- If you genuinely find nothing, return an empty "issues" array.
- Use "requests" ONLY when you cannot judge a concern without seeing code outside the diff.
  The orchestrator will answer requests and re-run you once. Keep requests minimal and targeted.
- Do not include prose outside the JSON block.`;

export function buildReviewerSystemPrompt(id: ReviewerId): string {
  const spec = REVIEWERS[id];
  return `${spec.focus}\n\nYou review a single pull request. You only see the diff (plus any context you explicitly request).\n${OUTPUT_CONTRACT}`;
}

export function buildReviewerTask(meta: PRMeta, diff: string, extraContext?: string): string {
  const head = [
    `PR #${meta.number}: ${meta.title}`,
    `Branch: ${meta.headRefName} -> ${meta.baseRefName}`,
    `Stats: ${meta.changedFiles} files, +${meta.additions}/-${meta.deletions}`,
    meta.body ? `\nDescription:\n${meta.body}` : "",
  ]
    .filter(Boolean)
    .join("\n");

  const ctxBlock = extraContext
    ? `\n\n## Additional context you requested\n${extraContext}\n`
    : "";

  return `Review the following pull request diff.\n\n## PR\n${head}\n\n## Diff\n\`\`\`diff\n${diff}\n\`\`\`${ctxBlock}`;
}

export const SUMMARIZER_SYSTEM = [
  "You summarize a pull request for a human reviewer who is deciding whether to read it in detail.",
  "Be accurate and concise. Detect whether the PR makes a MAJOR behaviour change",
  "(new/changed runtime behaviour, API/contract changes, permission/policy changes, data migrations,",
  "or anything that changes what the system does at runtime) versus a cosmetic/refactor/docs-only change.",
  "",
  "Respond with EXACTLY ONE fenced JSON block:",
  "```json",
  '{ "summary": "markdown walkthrough of the change, grouped logically", "majorBehaviorChange": true, "riskNotes": "one-line risk note" }',
  "```",
  "No prose outside the JSON block.",
].join("\n");

export function buildSummarizerTask(meta: PRMeta, diff: string): string {
  return `Summarize this PR.\n\nPR #${meta.number}: ${meta.title}\nStats: ${meta.changedFiles} files, +${meta.additions}/-${meta.deletions}\n${meta.body ? `\nDescription:\n${meta.body}\n` : ""}\n## Diff\n\`\`\`diff\n${diff}\n\`\`\``;
}

export const TRIAGE_SYSTEM = [
  "You are the orchestrator triaging issues found by several adversarial code reviewers.",
  "De-duplicate: merge issues that describe the SAME underlying problem (even if worded differently",
  "or reported by different reviewers) into a single issue. When merging, keep the HIGHEST severity,",
  "combine rationales, and list every reporting reviewer in 'reporters'.",
  "Drop issues that are clearly noise, redundant restatements, or pure praise.",
  "Then sort the final list by criticality: critical, high, medium, low, info.",
  "",
  "Respond with EXACTLY ONE fenced JSON block:",
  "```json",
  '{ "issues": [ { "severity": "high", "category": "security", "title": "...", "file": "...", "line": 1, "rationale": "...", "recommendation": "...", "reporters": ["security","general"] } ] }',
  "```",
  "No prose outside the JSON block.",
].join("\n");

export function buildTriageTask(labelled: string): string {
  return `Here are raw issues from multiple reviewers. De-duplicate, merge, and sort by criticality.\n\n${labelled}`;
}

// ---------------------------------------------------------------------------
// Complexity tiering
// ---------------------------------------------------------------------------

export function baseTier(meta: PRMeta): Tier {
  const lines = meta.additions + meta.deletions;
  if (meta.changedFiles <= 1 && lines < 5) return "low";
  if (meta.changedFiles >= 10 || lines >= 200) return "high";
  return "medium";
}

/** majorBehaviorChange can only escalate (never de-escalate) the tier. */
export function finalTier(base: Tier, majorBehaviorChange: boolean): Tier {
  if (majorBehaviorChange) return "high";
  return base;
}

export function reviewersForTier(tier: Tier): ReviewerId[] {
  switch (tier) {
    case "low":
      return ["general"];
    case "medium":
      return ["security", "code-quality", "general"];
    case "high":
      return ["general", "security", "code-quality", "ci", "performance"];
  }
}

export function reviewerTitle(id: ReviewerId): string {
  return REVIEWERS[id].title;
}
