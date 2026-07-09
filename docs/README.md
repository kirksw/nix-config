# Repository Knowledge Store

This directory is the versioned system of record for project knowledge.
`AGENTS.md` is the short map; follow its links here for task-specific context.

## Index

| Knowledge | Location | Use it for |
| --- | --- | --- |
| Architecture | [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | System boundaries, composition flow, and invariants |
| Design | [`design/`](./design/) | Stable principles and design-document catalog |
| Decisions | [`adrs/`](./adrs/) | Durable architectural decisions and their rationale |
| Execution plans | [`plans/`](./plans/) | General active and completed multi-step work |
| Agent engineering | [`agents/`](./agents/) | Agent guides and the existing agent feature workflow |
| References | [`reference/`](./reference/) | Repository-local external or generated reference material |
| Technical debt | [`BACKLOG.md`](./BACKLOG.md) | Prioritized follow-up work |
| Secrets | [`SECRETS.md`](./SECRETS.md) | Secret-management guidance |

## Documentation Rules

- Update the source-of-truth document in the same change as the behavior it describes.
- Prefer links over copying guidance into `AGENTS.md` or another index.
- Record durable design decisions as ADRs; record temporary execution detail in a plan.
- Put general plans in `plans/`; keep agent-feature plans in `agents/` until that workflow is intentionally migrated.
- Include a status and last-verified date in design documents so stale knowledge is visible.
- Add unfinished follow-up work to `BACKLOG.md` with priority, effort, and source.

## Adding Knowledge

1. Choose the narrowest category from the index.
2. Link the new document from that category's index.
3. Link it from `AGENTS.md` only when it is a common entry point.
4. Verify links and any commands or file paths stated in the document.
