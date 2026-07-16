---
name: spec-package
description: Build, challenge, review, and document an executable spec with tasks
---

## the-architect
phase: Specification
label: Draft the spec
as: spec
output: spec.md
progress: true

Create an executable spec for {task}. Include: problem statement, Definition of Done, scope boundaries, assumptions, risks, validation plan, and the proposed task breakdown needed to ship it.

## 10xBEAST
phase: Challenge
label: Stress the spec
reads: spec.md
as: challenge
output: challenge.md
progress: true

Challenge {outputs.spec} hard. Call out missing tasks, weak assumptions, hidden dependencies, sequencing problems, and needless complexity. Return the minimum changes needed to make the spec executable.

## bottleneck
phase: Review
label: Review the spec
reads: spec.md
as: review
output: review.md
progress: true

Review the spec for correctness, completeness, sequencing, and acceptance quality. Use {outputs.spec} and {outputs.challenge}. Return a concise pass/fail review plus the smallest fixes needed.

## the-architect
phase: Revision
label: Finalize the spec
reads: challenge.md
as: final_spec
output: final-spec.md
progress: true

Revise the spec using {outputs.challenge} and {outputs.review}. Produce the final spec and task breakdown, or say clearly why the task should be re-scoped before execution.

## scribe
phase: Documentation
label: Record the spec
reads: final-spec.md
progress: true

Write or update the durable paper trail for {task}: the final spec, Definition of Done, task breakdown, validation plan, and open risks or follow-ups. If no durable documentation should change, say so explicitly and explain why.
