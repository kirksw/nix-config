---
name: task
description: Execute one scoped task against an approved spec, then review and document it
---

## explore
phase: Discovery
label: Map the package
as: context
output: context.md

Analyze the approved task for {task}. Identify the exact files, interfaces, dependencies, constraints, and validation needed to complete only this package. Call out any spec ambiguity or external dependency that should block execution.

## code-monkey
phase: Implementation
label: Ship the package
reads: context.md
as: implementation
output: implementation.md
progress: true

Implement only the scoped task for {task} using {outputs.context}. Keep boundaries tight. Run the smallest sensible validation before you finish. If you hit a real blocker, escalate to 10xBEAST instead of widening scope silently.

## bottleneck
phase: Review
label: Review the package
reads: implementation.md
as: review
output: review.md
progress: true

Review the package result for correctness, boundary drift, regressions, and missing verification. Return only concrete issues and the smallest fixes needed.

## code-monkey
phase: Remediation
label: Resolve review findings
reads: review.md
as: resolved
output: resolved.md
progress: true

Apply the valid findings from {outputs.review}. If there are no real issues, say so briefly and leave the code unchanged. Re-run the smallest relevant validation and summarize what changed.

## reviewer
phase: Acceptance
label: Final pass
reads: resolved.md
as: final_review
output: final-review.md
progress: true

Do a final acceptance pass for this task. Confirm whether the package appears complete against its local Definition of Done and note any dependency or integration follow-ups.

## scribe
phase: Documentation
label: Write the package log
reads: final-review.md
progress: true

Write or update the durable paper trail for this task: what changed, what was validated, and any open risks, integration notes, or follow-ups. If no durable documentation should change, say so explicitly and explain why.
