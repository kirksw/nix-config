# PR Reviewer Extension

`/pr-review [number]` — review a GitHub PR with adversarial reviewers scaled to
the PR's complexity.

## Flow

1. **Pick a PR** — interactive list (`gh pr list`), or pass a number directly.
2. **Summary + walkthrough** — a summarizer pass produces a walkthrough and
   detects whether the PR is a *major behaviour change*. You're asked whether
   you want to be walked through the changes before reviews start.
3. **Adversarial reviewers** — spawned as isolated `pi` subprocesses (no tools),
   fed only the diff. Each emits structured JSON issues and may request more
   context (`read`/`grep`), which the orchestrator fulfills for one follow-up
   round.
4. **Triage** — issues are de-duplicated/merged across reviewers and sorted by
   criticality.
5. **Review** — issues are presented one at a time, most critical first. You can
   optionally dump the full report into the editor.

## Complexity tiers

| Tier   | Trigger                                              | Reviewers |
|--------|------------------------------------------------------|-----------|
| low    | ≤1 file changed **and** <5 lines                     | general |
| medium | <10 files **and** <200 lines                         | security, code-quality, general |
| high   | ≥10 files **or** ≥200 lines **or** major behaviour change | general, security, code-quality, ci, performance |

A detected major behaviour change can only *escalate* the tier to high.

## Notes

- Reviewers inherit the parent session's model.
- The `ci` reviewer is static-analysis only (it never runs builds/tests).
- Requires the `gh` CLI authenticated against the repo.

## Files

| File | Responsibility |
|------|----------------|
| `index.ts` | `/pr-review` command + orchestration |
| `reviewers.ts` | reviewer prompts, summarizer/triage prompts, tiering |
| `runner.ts` | `gh` helpers, `pi` subprocess runner, info-request fulfillment |
| `ui.ts` | PR picker, summary view, issue navigator, report builder |
| `types.ts` | shared types |
