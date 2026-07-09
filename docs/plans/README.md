# Execution Plans

Use a checked-in execution plan when work spans multiple steps, has meaningful
trade-offs, or needs a durable progress and decision log.

## Layout

- [`active/`](./active/): work currently in progress.
- [`completed/`](./completed/): finished plans retained as implementation history.
- [`../BACKLOG.md`](../BACKLOG.md): scoped follow-up work not yet active.

Agent feature work continues to use the established [`../agents/`](../agents/)
workflow. Do not duplicate a plan in both locations.

## Minimum Plan Content

- Problem statement and Definition of Done
- Scope and non-goals
- Approach and significant decisions
- Progress or status
- Validation performed
- Open risks and backlog follow-ups
