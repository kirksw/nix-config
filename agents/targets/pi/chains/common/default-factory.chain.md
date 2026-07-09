---
name: default-factory
description: Investigate, implement, review, and document a bounded engineering task
---

## explore
phase: Discovery
label: Gather context
as: context
output: context.md

Investigate the codebase for {task}. Identify the relevant files, constraints, dependencies, and the smallest viable implementation plan. Restate any missing assumptions or Definition of Done gaps. Do not edit files.

## code-monkey
phase: Implementation
label: Ship first pass
reads: context.md
as: implementation
output: implementation.md
progress: true

Implement {task} using {outputs.context}. Run the smallest sensible validation before you finish. If you get stuck on a real blocker, escalate to 10xBEAST instead of spinning. Summarize changed files, validation, and residual risks.

## bottleneck
phase: Review
label: Review for issues
reads: implementation.md
as: review
output: review.md
progress: true

Review the implementation for correctness, maintainability, regressions, and missing verification. Use {outputs.implementation} as the primary context. Return only concrete issues and the smallest fixes that would close them.

## code-monkey
phase: Remediation
label: Resolve review findings
reads: review.md
as: resolved
output: resolved.md
progress: true

Apply the valid issues from {outputs.review}. If there are no real issues, say so briefly and leave the code unchanged. Re-run the smallest relevant validation and summarize what changed.

## reviewer
phase: Acceptance
label: Final pass
reads: resolved.md
as: final_review
output: final-review.md
progress: true

Do a final acceptance pass on the result for {task}. Confirm whether the Definition of Done appears met, note any remaining gaps, and keep the answer concise.

## scribe
phase: Documentation
label: Write the paper trail
reads: final-review.md
progress: true

Write or update the durable paper trail for {task}: what changed, what was validated, and any open risks or follow-ups. If no durable documentation should change, say so explicitly and explain why.
