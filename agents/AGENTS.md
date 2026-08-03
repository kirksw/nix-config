# Working Agreement

## General

- Use subagents only when requested or when clear specialist or parallel value outweighs the overhead.
- Treat repository-local instructions and source files as authoritative; ask when ambiguity could cause an incorrect or risky result or when approval is required.
- Make the smallest complete change, follow existing patterns, and avoid unrelated refactoring.
- Never manually modify `CHANGELOG.md` or generated files, expose secrets, perform destructive actions without explicit approval, or add an agent as a commit co-author.

## Principles

Use project-defined principles when they exist.
Unless instructed otherwise, prefer quality, simplicity, robustness, scalability, and long-term maintainability over short-term development cost.

For work that requires design or trade-off decisions and has no applicable principles:

1. Propose the minimum task-specific principles needed to guide decisions.
2. Resolve conflicts or ambiguity.
3. Get explicit approval before designing or implementing.

Treat approved principles as invariants.
Keep requirements and changes consistent with them, and test affected invariants.
If a principle must change, stop and request approval.

## Validation

- Start bug fixes by reproducing the issue at the closest practical level to the end-user experience; prefer E2E reproduction for user-facing behavior.
- During end-to-end testing, visually inspect the rendered UI and use screenshots when useful; hold UI work to a high visual standard.
- Before finishing, inspect the diff and run the narrowest relevant checks; user-specified acceptance checks must pass.
- Fix task-caused lint failures, test failures, and flaky tests; report unrelated issues, blockers, and remaining risks, and do not claim completion while work is partial or checks fail.

## Communication

- Follow the principles of ASD-STE100, but do not enforce its restricted dictionary.
- Optimize for concise, clear, natural technical communication.
- Lead with the answer, do not restate the request, and state each point once.
- Include only information needed to understand or act.
- Prefer bullets for multiple points and expand only when necessary for correctness.
- For completed work, report what changed, validation performed, and remaining blockers or risks.
- Cite relevant file paths inline.
- When substantially editing long Markdown files, put each full sentence on its own physical line while preserving normal Markdown structure.
- Generating infographics is a good way to ensure alignment of complex concepts (information dense)

## Personal Context

- When work would benefit from the user's viewpoints, read `~/OPINIONS.md` if it exists.
- When speaking or posting on behalf of the user, read `~/VOICE.md` if it exists.
