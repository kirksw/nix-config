/**
 * PR Reviewer Extension
 *
 * `/pr-review [number]` — pick a GitHub PR, optionally get a walkthrough, then
 * spin up adversarial reviewers scaled to the PR's complexity. Reviewers run as
 * isolated `pi` subprocesses fed only the diff (they may request more context).
 * The orchestrator de-duplicates issues, sorts by criticality, and presents
 * them one at a time.
 *
 * Complexity tiers:
 *   low    (<=1 file, <5 lines)            -> general
 *   medium (<10 files, <200 lines)         -> security, code-quality, general
 *   high   (>=10 files OR >=200 lines, or  -> general, security, code-quality,
 *           a major behaviour change)         ci, performance
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import {
  baseTier,
  buildReviewerSystemPrompt,
  buildReviewerTask,
  buildSummarizerTask,
  buildTriageTask,
  finalTier,
  reviewersForTier,
  reviewerTitle,
  SUMMARIZER_SYSTEM,
  TRIAGE_SYSTEM,
} from "./reviewers.js";
import { extractJson, fulfillRequests, getPRDiff, getPRMeta, listPRs, runPi } from "./runner.js";
import {
  type Issue,
  type PRMeta,
  type ReviewerId,
  type ReviewerOutput,
  type ReviewerResult,
  SEVERITY_RANK,
  type Severity,
  type SummaryOutput,
  type Tier,
} from "./types.js";
import { buildReport, navigateIssues, pickPR, showSummary } from "./ui.js";

const MAX_ROUNDS = 2;
const STATUS_KEY = "pr-reviewer";

const VALID_SEVERITIES: Severity[] = ["critical", "high", "medium", "low", "info"];

function normSeverity(s: unknown): Severity {
  return VALID_SEVERITIES.includes(s as Severity) ? (s as Severity) : "info";
}

function modelString(ctx: ExtensionContext): string | undefined {
  const m = ctx.model;
  if (!m) return undefined;
  return m.provider ? `${m.provider}/${m.id}` : m.id;
}

function runPiFailure(res: Awaited<ReturnType<typeof runPi>>): string {
  const reason = res.stopReason ?? `exit ${res.exitCode}`;
  const stderr = res.stderr.trim();
  return stderr ? `${reason}: ${stderr.slice(0, 500)}` : reason;
}

/** Run one reviewer with up to MAX_ROUNDS, fulfilling info requests between rounds. */
async function runReviewer(
  ctx: ExtensionContext,
  id: ReviewerId,
  meta: PRMeta,
  diff: string,
  model: string | undefined,
): Promise<ReviewerResult> {
  const system = buildReviewerSystemPrompt(id);
  const collected: Issue[] = [];
  let extraContext: string | undefined;

  for (let round = 1; round <= MAX_ROUNDS; round++) {
    const task = buildReviewerTask(meta, diff, extraContext);
    let res: Awaited<ReturnType<typeof runPi>>;
    try {
      res = await runPi(`reviewer-${id}`, { cwd: ctx.cwd, model, systemPrompt: system, task, signal: ctx.signal });
    } catch (err) {
      return { reviewer: id, issues: collected, ok: collected.length > 0, error: (err as Error).message };
    }
    if (res.stopReason === "aborted") return { reviewer: id, issues: collected, ok: false, error: "aborted" };
    if (res.exitCode !== 0 && !res.text.trim()) {
      return { reviewer: id, issues: collected, ok: collected.length > 0, error: runPiFailure(res) };
    }

    const parsed = extractJson<ReviewerOutput>(res.text);
    if (!parsed) {
      return {
        reviewer: id,
        issues: collected,
        ok: collected.length > 0,
        error: collected.length > 0 ? undefined : `could not parse output (${runPiFailure(res)})`,
      };
    }

    for (const issue of parsed.issues ?? []) {
      collected.push({ ...issue, severity: normSeverity(issue.severity), category: id });
    }

    const requests = parsed.requests ?? [];
    if (round < MAX_ROUNDS && requests.length > 0) {
      extraContext = await fulfillRequests(ctx.cwd, requests);
      continue;
    }
    break;
  }

  return { reviewer: id, issues: collected, ok: true };
}

function localTriage(issues: Issue[]): Issue[] {
  return [...issues]
    .map((i) => ({ ...i, reporters: i.reporters ?? [i.category] }))
    .sort((a, b) => SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity]);
}

async function triage(
  ctx: ExtensionContext,
  issues: Issue[],
  model: string | undefined,
): Promise<Issue[]> {
  if (issues.length <= 1) return localTriage(issues);
  const labelled = JSON.stringify(
    issues.map((i) => ({
      reporter: i.category,
      severity: i.severity,
      title: i.title,
      file: i.file,
      line: i.line,
      rationale: i.rationale,
      recommendation: i.recommendation,
    })),
    null,
    2,
  );
  const res = await runPi("triage", {
    cwd: ctx.cwd,
    model,
    systemPrompt: TRIAGE_SYSTEM,
    task: buildTriageTask(labelled),
    signal: ctx.signal,
  });
  const parsed = extractJson<{ issues: Issue[] }>(res.text);
  if (!parsed?.issues) return localTriage(issues);
  const merged = parsed.issues.map((i) => ({ ...i, severity: normSeverity(i.severity) }));
  return merged.sort((a, b) => SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity]);
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("pr-review", {
    description: "Review a GitHub PR with adversarial reviewers scaled to complexity. Usage: /pr-review [number]",
    handler: async (args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/pr-review requires interactive (tui) mode", "error");
        return;
      }

      const setStatus = (s: string | undefined) =>
        ctx.ui.setStatus(STATUS_KEY, s ? ctx.ui.theme.fg("accent", `● ${s}`) : undefined);

      try {
        // 1. Resolve PR number.
        let prNumber: number | null = null;
        const argNum = Number.parseInt((args || "").trim(), 10);
        if (Number.isFinite(argNum) && argNum > 0) {
          prNumber = argNum;
        } else {
          setStatus("listing PRs");
          let prs;
          try {
            prs = await listPRs(ctx.cwd);
          } catch (err) {
            ctx.ui.notify(`gh pr list failed: ${(err as Error).message}`, "error");
            return;
          }
          setStatus(undefined);
          if (prs.length === 0) {
            ctx.ui.notify("No open PRs found in this repo", "warning");
            return;
          }
          prNumber = await pickPR(ctx, prs);
        }
        if (!prNumber) {
          ctx.ui.notify("Cancelled", "info");
          return;
        }

        // 2. Fetch metadata + diff.
        setStatus(`fetching PR #${prNumber}`);
        let meta: PRMeta;
        let diff: string;
        try {
          meta = await getPRMeta(ctx.cwd, prNumber);
          diff = await getPRDiff(ctx.cwd, prNumber);
        } catch (err) {
          ctx.ui.notify(`Failed to fetch PR #${prNumber}: ${(err as Error).message}`, "error");
          return;
        }
        const model = modelString(ctx);

        // 3. Base tier + summary (summary also detects major behaviour change).
        const base = baseTier(meta);
        setStatus("summarizing changes");
        const sumRes = await runPi("summarizer", {
          cwd: ctx.cwd,
          model,
          systemPrompt: SUMMARIZER_SYSTEM,
          task: buildSummarizerTask(meta, diff),
          signal: ctx.signal,
        });
        const sum = extractJson<SummaryOutput>(sumRes.text);
        if (!sum) {
          ctx.ui.notify(`Summary failed: ${runPiFailure(sumRes)}`, "warning");
        }
        const summaryText = sum?.summary || sumRes.text.trim() || "(no summary available)";
        const major = sum?.majorBehaviorChange ?? false;
        const tier: Tier = finalTier(base, major);
        setStatus(undefined);

        // 4. Walkthrough offer.
        const wantWalk = await ctx.ui.confirm(
          `PR #${meta.number}: ${meta.title}`,
          `${meta.changedFiles} files, +${meta.additions}/-${meta.deletions}. Walk you through the changes first?`,
        );
        if (wantWalk) {
          await showSummary(ctx, `PR #${meta.number} walkthrough`, summaryText);
        }

        // 5. Select + run reviewers.
        const roster = reviewersForTier(tier);
        const escalated = major && base !== "high" ? " (escalated: major behaviour change)" : "";
        ctx.ui.notify(
          `Tier: ${tier}${escalated} — ${roster.map(reviewerTitle).join(", ")}`,
          "info",
        );

        let done = 0;
        setStatus(`reviewing 0/${roster.length}`);
        const results = await Promise.all(
          roster.map(async (id) => {
            const r = await runReviewer(ctx, id, meta, diff, model);
            done++;
            setStatus(`reviewing ${done}/${roster.length}`);
            return r;
          }),
        );
        setStatus(undefined);

        const failed = results.filter((r) => !r.ok && r.error);
        for (const f of failed) {
          ctx.ui.notify(`${reviewerTitle(f.reviewer)} failed: ${f.error}`, "warning");
        }

        const allIssues = results.flatMap((r) => r.issues);
        if (allIssues.length === 0) {
          ctx.ui.notify("No issues found by any reviewer ✓", "info");
          return;
        }

        // 6. De-dup + sort, then present.
        setStatus("triaging issues");
        const triaged = await triage(ctx, allIssues, model);
        setStatus(undefined);

        ctx.ui.notify(`${triaged.length} issue(s) after de-dup. Opening reviewer…`, "info");
        await navigateIssues(ctx, triaged);

        // 7. Offer a report dump.
        const dump = await ctx.ui.confirm("Save report?", "Load the full triaged report into the editor?");
        if (dump) {
          ctx.ui.setEditorText(buildReport(meta.number, meta.title, tier, triaged));
        }
      } catch (err) {
        ctx.ui.notify(`PR review failed: ${(err as Error).message}`, "error");
      } finally {
        setStatus(undefined);
      }
    },
  });
}
