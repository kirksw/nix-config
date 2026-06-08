# Extraction Rules

## What Counts As A Heuristic

A good heuristic is actionable in a future session:

- When this condition appears, do this.
- Before using this tool, check this.
- If this error appears, try this recovery path.
- If the user corrects this behavior, avoid repeating it.

Reject observations that are merely narrative, one-off, or obvious.

## Signal Definitions

### Complex Completed Task

Use this when a session shows:

- 5 or more tool calls, shell commands, MCP calls, or explicit step transitions.
- A final completion signal such as tests passing, build succeeding, PR opened, file changed, or user acceptance.
- Cross-file or cross-tool coordination.

Extract:

- The stable sequence that worked.
- Preconditions that made it work.
- Validation commands that proved it.

### Error Recovery

Use this when a session shows:

- Failed command, exception, sandbox denial, missing dependency, broken build, flaky service, or failed test.
- A subsequent diagnosis and successful fix, workaround, or clear escalation path.

Extract:

- Error signature.
- Root cause if known.
- Recovery action.
- What should be checked earlier next time.

### User Workflow Correction

Use this when the user:

- Says an approach is wrong, too broad, too slow, unsafe, or not what they asked.
- Supplies missing context that changes the plan.
- Corrects a naming, command, environment, or source-of-truth assumption.

Extract:

- The incorrect agent behavior.
- The user preference or rule.
- The future trigger for applying it.

### Reusable Non-Trivial Workflow

Use this when a session demonstrates a multi-step workflow worth repeating:

- Build-test-switch loop.
- Debug-run-inspect-patch-validation loop.
- Session migration or generated-config workflow.
- Cross-tool inspection workflow.

Extract:

- Step sequence.
- Tool choices.
- Stop conditions.
- Known pitfalls.

## Confidence Labels

Use these labels:

- High: repeated evidence or direct user correction.
- Medium: one completed session with clear outcome.
- Low: plausible pattern but incomplete validation.

## Filtering

Skip sessions when:

- They contain only simple Q&A.
- Tool use is incidental and below the complexity threshold.
- The outcome is unknown and there is no reusable recovery.
- The content is mostly secrets, credentials, or private third-party data.
