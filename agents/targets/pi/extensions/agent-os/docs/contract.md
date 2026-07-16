# Agent OS Contract

This file travels with the `agent-os` extension and is the single source of truth for its three-tier model:

```text
OS → ThreadOS → FactoryOS
```

External Agent OS specifications are not authoritative. This contract describes the current implementation and marks every required implementation delta with a `Contract change:` callout.

Grounding sources:

- `core/schema.ts` — current record interfaces and vocabulary.
- `core/markdown-store.ts` — Markdown parsing, discovery, and writers.
- `core/workpackage.ts` — workpackage discovery and status handling.
- `core/policy.ts` — tier capability boundaries.
- `render/markdown.ts`, `render/thread-readme.ts`, `render/tracker.ts`, `render/focus.ts` — generated views and markers.

## 1. Three tiers and ownership

| Tier | Binding | Read boundary | Write boundary | Owns |
| --- | --- | --- | --- | --- |
| **OS** | No thread selected | Entire workspace | Entire workspace | `inbox/`, `threads/`, `wiki/`, `runtime/`, `outcomes/` |
| **ThreadOS** | One thread selected | `threads/<thread>/` | Thread-owned files, plus that thread's `workpackages/<wp>/package.md` and `input/` | Thread records and workpackage inputs |
| **FactoryOS** | One thread and one workpackage selected | `threads/<thread>/workpackages/<wp>/` | `runs/` and `output/` inside the selected bundle | Execution data and proposed output |

These boundaries are enforced by `core/policy.ts` through `canRead`, `canWrite`, `assertPolicyRead`, and `assertPolicyWrite`. The policy is a capability boundary, not merely a display mode. OS mode is intentionally unrestricted inside the workspace; ThreadOS and FactoryOS are confined to their selected roots.

The record ownership is:

- **OS:** workspace-level `Outcome` records, unassigned inbox records, and cross-thread coordination.
- **ThreadOS:** `Thread`, `Blocker`, `Decision`, `Candidate`, and `Metric` records, plus the `Workpackage` specification and inputs.
- **FactoryOS:** a selected `Workpackage` bundle; it writes only working data under `runs/` and `output/`, not canonical ThreadOS records.

> Contract change: adopt the five-directory workspace root and the ownership table above in workspace initialization and validation. Current policy permits the required boundaries but does not create or validate all canonical directories.

## 2. Frontmatter and Markdown rules

Every canonical record is a Markdown document with a flat frontmatter block followed by a Markdown body:

```markdown
---
type: Thread
id: thread:example
---

# Human-readable body
```

Canonical `type` values are `Outcome`, `Thread`, `Workpackage`, `Blocker`, `Decision`, `Candidate`, and `Metric`. Readers compare `type` case-insensitively. The body is the fallback for `text` fields. Canonical timestamps are ISO-8601 strings.

`parseMarkdownDocument()` in `core/markdown-store.ts` currently accepts only scalar, single-line `key: value` entries. It recognizes quoted strings, booleans, numbers, and `null`; it does not parse YAML arrays, objects, comments, or multiline values. Structured fields below are therefore normative contract data, but are not yet readable by the current parser unless serialized using a future structured representation.

> Contract change: replace the scalar-only parser/writer with structured frontmatter support, or define and implement an equivalent lossless serialization for structured fields.

### 2.1 Outcome

Canonical location: `outcomes/<id>.md`.

| Field | Required | Type / values |
| --- | --- | --- |
| `type` | yes | `Outcome` |
| `id` | yes | string; stable outcome identifier |
| `title` | yes | string |
| `thread` | no | string thread slug |
| `workpackage` | no | string workpackage identifier |
| `goal` | yes | string |
| `result` | no | string |
| `state` | yes | `planned`, `in_progress`, `done`, `blocked`, or `archived` |
| `createdAt` | yes | ISO-8601 string |
| `updatedAt` | no | ISO-8601 string |
| `closedAt` | no | ISO-8601 string |

`Outcome` is not represented in `core/schema.ts`, is not returned by `readMarkdownData()`, and has no writer in `core/markdown-store.ts`.

> Contract change: add `OutcomeRecord`, outcome discovery/persistence, and `LifeOsData.outcomes`.

### 2.2 Thread

Canonical location: `threads/<thread>/README.md`.

| Field | Required | Type / values |
| --- | --- | --- |
| `type` | yes | `Thread` |
| `id` | yes | string; normally `thread:<slug>` |
| `slug` | yes | string; directory-safe thread slug |
| `title` | yes | string |
| `kind` | yes | string; open vocabulary (current examples include `idea`, `research`, `project`, `product`, `concept`, `ops`) |
| `status` | yes | string; current code treats it as free text |
| `stage` | yes | string; current code treats it as free text |
| `createdAt` | yes | ISO-8601 string |
| `updatedAt` | no | ISO-8601 string |
| `linear` | no | object with `initiatives` and `projects`, each an array of string identifiers |
| `kbs` | no | array of objects with required `id` and `scope`, plus optional `note` |
| `repos` | no | array of repository identifiers or paths |
| `salience` | no | number |
| `impact` | no | number |
| `confidence` | no | number |
| `urgency` | no | number |
| `effort` | no | number |
| `manualOverride` | no | number |

`path` is a derived `ThreadRecord.path` value (`threads/<slug>`), not canonical frontmatter. `core/markdown-store.ts` computes it while reading and `writeThreadDocument()` does not emit it.

Current support:

- `ThreadRecord` in `core/schema.ts` supports the scalar fields through `manualOverride`.
- `readMarkdownThreads()` reads `threads/<slug>/README.md`, accepts `type: Thread` case-insensitively, and derives missing `id`, `slug`, `title`, `kind`, `status`, and `stage` defaults.
- `writeThreadDocument()` currently emits only `type`, `title`, `kind`, `stage`, `status`, and `timestamp`.
- `linear`, `kbs`, and `repos` are not persisted by the scalar parser/writer.
- The reader trusts the directory entry and frontmatter independently; a frontmatter `slug` can differ from the containing directory name.

> Contract change: persist the complete Thread schema, including `id`, `slug`, `createdAt`/`updatedAt`, `linear`, `kbs`, and `repos`; keep `path` derived rather than duplicating it in frontmatter, and require `slug` to match its directory-safe path.

`linear` is deliberately split into the two external-reference groups `initiatives` and `projects`. Each value is a stable Linear identifier. `kbs` records knowledge-base references as `{id, scope, note}`. `repos` records repository references without requiring the extension to guess or clone a repository.

### 2.3 Workpackage

Canonical location and bundle root:

```text
threads/<thread>/workpackages/<wp>/
├── package.md
├── input/
├── runs/
└── output/
```

Canonical `package.md` frontmatter:

| Field | Required | Type / values |
| --- | --- | --- |
| `type` | yes | `Workpackage` |
| `id` | yes | string; stable workpackage identifier |
| `title` | yes | string |
| `thread` | yes | string thread slug |
| `status` | yes | `draft`, `specced`, `running`, `review`, `done`, or `failed` |
| `createdAt` | yes | ISO-8601 string |
| `updatedAt` | no | ISO-8601 string |
| `goal` | no | string |
| `notes` | no | string |

`core/workpackage.ts` currently reads `id`, `workpackage`, or `slug`, plus `title` and `status`, using a flat line regex. `createWorkpackage()` writes `type`, `id`, `title`, `thread`, `status: draft`, and `timestamp`. Workpackages are not part of `LifeOsData` and are not discovered by `readMarkdownData()`.

> Contract change: make `Workpackage` a first-class record with canonical timestamp fields, canonical `status`, and bundle validation. `timestamp` is a compatibility alias during migration only.

### 2.4 Blocker

Canonical location: `threads/<thread>/blockers/<id>.md` (or `inbox/blockers/<id>.md` before assignment).

| Field | Required | Type / values |
| --- | --- | --- |
| `type` | yes | `Blocker` |
| `id` | yes | string |
| `text` | yes | string; body fallback is allowed |
| `thread` | no | string thread slug |
| `threadId` | no | normalized string identifier; `thread` and `threadId` are aliases |
| `status` | yes | `open` or `resolved` |
| `createdAt` | yes | ISO-8601 string |
| `updatedAt` | no | ISO-8601 string |

`BlockerRecord` in `core/schema.ts` uses `threadId`. `core/markdown-store.ts` accepts either `thread` or `threadId`, normalizes the association, and treats only `resolved` as resolved; missing status defaults to `open`. There is no Blocker-specific writer or required-field validation, and typed Markdown is currently accepted recursively from any workspace directory.

> Contract change: standardize on one serialized thread-reference field (`thread`) while retaining `threadId` as a read-compatibility alias until migration is complete; add canonical Blocker persistence/validation and enforce the `blockers/` or unassigned inbox location.

### 2.5 Decision

Canonical location: `threads/<thread>/decisions/<id>.md` (or `inbox/decisions/<id>.md` before assignment).

| Field | Required | Type / values |
| --- | --- | --- |
| `type` | yes | `Decision` |
| `id` | yes | string |
| `text` | yes | string; body fallback is allowed |
| `thread` | no | string thread slug |
| `threadId` | no | normalized string identifier; alias for `thread` |
| `source` | yes | `pi` |
| `createdAt` | yes | ISO-8601 string |
| `updatedAt` | no | ISO-8601 string |

`DecisionRecord` requires `source: "pi"`; the reader supplies that value rather than preserving a serialized source. `writeMarkdownRecord()` currently writes `type`, `id`, optional `thread`, `status: accepted`, and `timestamp`, but not `source`. Discovery is recursive and does not enforce the canonical `decisions/` or unassigned inbox location.

> Contract change: write and validate canonical `source`, timestamps, and thread reference; enforce the canonical Decision location. Remove `status` from Decision documents or add it to the record schema; it is currently emitted but not modeled.

### 2.6 Candidate

Canonical location: `threads/<thread>/candidates/<id>.md` (or `inbox/candidates/<id>.md` before assignment).

| Field | Required | Type / values |
| --- | --- | --- |
| `type` | yes | `Candidate` |
| `id` | yes | string |
| `text` | yes | string; body fallback is allowed |
| `thread` | no | string thread slug |
| `threadId` | no | normalized string identifier; alias for `thread` |
| `source` | yes | `pi` |
| `status` | yes | `review`, `promoted`, or `rejected` |
| `reason` | no | string |
| `createdAt` | yes | ISO-8601 string |
| `updatedAt` | no | ISO-8601 string |

`CandidateRecord` in `core/schema.ts` supports the listed values. The reader defaults status to `review` and forces `source: "pi"`; `writeMarkdownRecord()` writes status and reason but does not serialize source. Discovery is recursive and does not enforce the canonical `candidates/` or unassigned inbox location.

> Contract change: persist and validate canonical `source`, timestamps, and thread reference; enforce the canonical Candidate location; and define promotion as an explicit user action rather than an implicit status-only side effect.

### 2.7 Metric

Canonical location: `threads/<thread>/artifacts/metrics/<id>.md` (the current reader previously accepted any workspace `.md` path with `type: metric`).

| Field | Required | Type / values |
| --- | --- | --- |
| `type` | yes | `Metric` |
| `id` | yes | string |
| `name` | yes | string; body fallback is allowed |
| `kind` | yes | `quantitative`, `qualitative`, `milestone`, or `capability` |
| `target` | no | string |
| `current` | no | string |
| `createdAt` | yes | ISO-8601 string |
| `updatedAt` | no | ISO-8601 string |

`MetricRecord` and `MetricKind` are defined in `core/schema.ts`; `readMarkdownMetrics()` reads these fields and defaults `kind` to `qualitative`. There is no Metric writer in `core/markdown-store.ts`.

> Contract change: define the canonical thread metric path and add a writer that preserves the complete Metric schema.

## 3. Workpackage lifecycle

The only canonical workpackage states are:

```text
draft → specced → running → review → done
                                      ↘ failed
```

Allowed transitions are exactly:

| From | To |
| --- | --- |
| `draft` | `specced` |
| `specced` | `running` |
| `running` | `review` |
| `review` | `done` |
| `review` | `failed` |

`done` and `failed` are terminal. No other transition, including a terminal-state reset or a direct jump, is allowed.

Current `core/workpackage.ts` behavior is not this state machine: it lowercases and normalizes arbitrary status text, then `listWorkpackages()` hides statuses in `CLOSED_STATUSES` (`closed`, `completed`, `done`, `failed`, `cancelled`, `canceled`). Creation starts at `draft`, but there is no transition API or validation.

> Contract change: replace free-text status normalization and the `CLOSED_STATUSES` blocklist with explicit validation of the lifecycle and allowed transitions above. The only terminal statuses are `done` and `failed`.

## 4. Canonical workspace layout

A workspace has exactly these five top-level directories:

```text
workspace/
├── inbox/
├── threads/
├── wiki/
├── runtime/
└── outcomes/
```

Root-level generated view files such as `TRACKER.md` and `FOCUS.md` are files, not additional top-level directories. `render/tracker.ts` and `render/focus.ts` currently write those views at the workspace root.

Every thread has exactly this canonical shape (directories may be empty):

```text
threads/<thread>/
├── README.md
├── plans/
├── research/
├── artifacts/
├── decisions/
├── blockers/
├── candidates/
├── sessions/
└── workpackages/
```

Every workpackage has exactly this bundle shape:

```text
threads/<thread>/workpackages/<wp>/
├── package.md
├── input/
├── runs/
└── output/
```

Current support and deltas:

- `core/markdown-store.ts` recursively scans Markdown below the workspace; thread discovery specifically requires `threads/<slug>/README.md`.
- `commands/thread.ts` creates `artifacts/` and uses `decisions/`, `blockers/`, and `candidates/`; it does not create or validate `plans/`, `research/`, or `sessions/`.
- `core/workpackage.ts` discovers immediate bundle directories containing `package.md`, while retaining legacy flat `.md` records.
- `runtime/` contains JSONL transport under OS, thread, and workpackage scopes; it is operational data, not Markdown records.
- Current code does not create or validate `wiki/` or `outcomes/`.

> Contract change: initialize and validate exactly the five top-level directories, create the complete thread shape, reject non-canonical workpackage bundles, and retire legacy flat workpackage resolution after migration.

## 5. Generated sections

The standardized generated-section markers are literal HTML comments:

```html
<!-- agent-os:generated:start -->
<!-- agent-os:generated:end -->
```

`render/markdown.ts` emits these markers when no existing marker pair is found. `render/thread-readme.ts`, `render/tracker.ts`, and `core/markdown-store.ts` use the same canonical pair. `replaceGeneratedBlock()` preserves human-authored text outside the generated block and refuses to modify files with duplicate markers from the selected marker family.

For migration compatibility, the current renderer also recognizes:

```html
<!-- agentic-os:generated:start -->
<!-- agentic-os:generated:end -->
```

and:

```html
<!-- lifeos:generated:start -->
<!-- lifeos:generated:end -->
```

Current rendering leaves a detected legacy pair unchanged with a migration warning. `migrateGeneratedMarkers()` is the explicit conversion path; it rewrites a single legacy pair to the canonical pair.

> Contract change: canonicalize all newly written sections to `agent-os:generated`; treat legacy pairs as read-only migration input and convert them explicitly rather than preserving them indefinitely.

## 6. Wiki/OS seam

Factory output is working data, not canonical knowledge:

```text
threads/<thread>/workpackages/<wp>/output/  # Factory working data
wiki/                                        # promoted, durable knowledge
```

Promotion from a workpackage's `output/` into `wiki/` is explicit, user-confirmed, and never automatic. A factory may prepare proposed files in `output/`; it may not write `wiki/`, promote by changing a status field, or silently copy output during rendering or reconciliation.

Current `core/policy.ts` permits FactoryOS writes only under `runs/` and `output/`. No current code path promotes output into `wiki/`, and `render/*` only updates generated views.

> Contract change: add an explicit promotion workflow that shows the proposed files and requires a user confirmation before writing to `wiki/`. Keep automatic promotion prohibited.

## 7. Adoption checklist

- [ ] Add `OutcomeRecord`, outcome discovery, and outcome persistence.
- [ ] Add structured, lossless persistence for Thread `linear`, `kbs`, and `repos`.
- [ ] Persist canonical timestamps and record sources; retain aliases only for migration.
- [ ] Make Workpackage a first-class record and enforce its state machine.
- [ ] Replace `CLOSED_STATUSES` with terminal-state handling for `done` and `failed`.
- [ ] Initialize and validate the five-directory root, complete thread shape, and bundle shape.
- [ ] Retire legacy flat workpackage resolution after migration.
- [ ] Canonicalize legacy generated markers through an explicit migration path.
- [ ] Add user-confirmed Factory `output/` → `wiki/` promotion.
