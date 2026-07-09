---
name: secure-factory
description: Investigate, implement, security-review, validate, and document a security-sensitive task
---

## explore
phase: Discovery
label: Gather context
as: context
output: context.md

Investigate the codebase for {task}. Identify trust boundaries, relevant files, constraints, dependencies, and the smallest viable implementation plan. Restate any missing assumptions or Definition of Done gaps. Do not edit files.

## code-monkey
phase: Implementation
label: Ship first pass
reads: context.md
as: implementation
output: implementation.md
progress: true

Implement {task} using {outputs.context}. Run the smallest sensible validation before you finish. If you get stuck on a real blocker, escalate to 10xBEAST instead of spinning. Summarize changed files, validation, and residual risks.

## code-red
phase: Security
label: Audit for vulnerabilities
reads: implementation.md
as: security_review
output: security-review.md
progress: true

Audit the implementation for authn/authz gaps, injection vectors, secret handling, unsafe defaults, data exposure, and privilege escalation paths. Return only concrete findings and the smallest safe remediations.

## code-monkey
phase: Hardening
label: Resolve security findings
reads: security-review.md
as: hardened
output: hardened.md
progress: true

Apply the valid findings from {outputs.security_review}. If there are no real issues, say so briefly and leave the code unchanged. Re-run the smallest relevant validation and summarize what changed.

## bottleneck
phase: Review
label: Review for issues
reads: hardened.md
as: review
output: review.md
progress: true

Review the hardened result for correctness, maintainability, regressions, and missing verification. Return only concrete issues and the smallest fixes that would close them.

## reviewer
phase: Acceptance
label: Final pass
reads: review.md
as: final_review
output: final-review.md
progress: true

Do a final acceptance pass on the result for {task}. Confirm whether the Definition of Done appears met, call out unresolved security or quality gaps, and keep the answer concise.

## scribe
phase: Documentation
label: Write the paper trail
reads: final-review.md
progress: true

Write or update the durable paper trail for {task}: what changed, what was validated, security-sensitive considerations, and any open risks or follow-ups. If no durable documentation should change, say so explicitly and explain why.
