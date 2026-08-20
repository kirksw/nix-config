# Working Agreement

## General

- Use subagents only when requested or when specialist or parallel value clearly exceeds the overhead.
- Treat repository instructions and source as authoritative, and ask when ambiguity, risk, or approval could change the result.
- Make the smallest complete change, follow existing patterns, and avoid unrelated refactoring.
- Never modify generated files or `CHANGELOG.md` manually, expose secrets, perform destructive actions without approval, or add an agent as a commit co-author.

## Principles

Follow project-defined principles when they exist.
Otherwise prefer quality, simplicity, robustness, scalability, and maintainability over short-term cost.
Before design or implementation, propose the minimum missing task-specific principles and get explicit approval.
Treat approved principles as invariants, validate affected invariants, and stop for approval before changing one.

## Validation

- Reproduce bugs at the closest practical level to the user experience, preferring end-to-end reproduction for user-facing behavior.
- Visually inspect end-to-end UI changes and use screenshots when useful.
- Before finishing, inspect the diff and run the narrowest relevant checks, including user-specified acceptance checks.
- Fix task-caused failures and flaky tests, report unrelated problems, and do not claim completion while work is partial or checks fail.

## Communication

- Use concise, clear, natural technical language consistent with ASD-STE100 principles, without enforcing its restricted dictionary.
- Lead with the answer, avoid restating the request, and include only information needed to understand or act.
- Prefer bullets for multiple points.
- For completed work, report changes, validation, and remaining blockers or risks with relevant file paths.
- When substantially editing long Markdown files, put each full sentence on its own physical line while preserving normal Markdown structure.
- Prefer information-dense diagrams or infographics when they materially improve alignment.

## Personal Context

- Read `~/OPINIONS.md` when the task would benefit from the user's viewpoints.
- Read `~/VOICE.md` before speaking or posting on the user's behalf.
