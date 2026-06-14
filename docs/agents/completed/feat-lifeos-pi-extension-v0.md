# LifeOS Native Pi Extension v0 Implementation Plan

Date: 2026-06-14
Status: implemented (manual-command v0)
Source design: `/Users/kisw/git/github.com/kirksw/lifeOS/workspaces/personal/threads/lifeos-memory-system/artifacts/lifeos-v0-design.md`

## Goal

Implement LifeOS as a native Pi extension in `nix-config`, with the `lifeOS` repo as the durable data/wiki surface.

v0 should prove the core workflow before adding automatic session-end capture or broad context injection.

## Repository boundary

Runtime implementation belongs here:

```text
nix-config/agents/targets/pi/extensions/lifeos/
```

Durable data and generated markdown belong in:

```text
/Users/kisw/git/github.com/kirksw/lifeOS/workspaces/<personal|lunar>/
```

Do not place Pi extension/runtime code in the `lifeOS` repo.

## v0 scope

### Commands

Implement slash-style Pi extension commands:

```text
/lifeos status
/lifeos thread <slug>
/lifeos new-thread <title> --kind <kind>
/lifeos capture [text]
/lifeos focus
/lifeos render
```

`/lifeos evolve` is planned but may come after basic render/capture works.

### Data store

Use git-stored JSONL records, one physical store per workspace:

```text
workspaces/personal/.lifeos/db/
workspaces/lunar/.lifeos/db/
```

Initial record files:

```text
threads.jsonl
metrics.jsonl
sessions.jsonl
decisions.jsonl
blockers.jsonl
artifacts.jsonl
concepts.jsonl
edges.jsonl
candidates.jsonl
evolution_proposals.jsonl
```

v0 implementation can query JSONL in memory. Keep records table-like so a future GlueSQL adapter can replace the query layer.

### Thread skeleton

`/lifeos new-thread` should create:

```text
workspaces/<scope>/threads/<slug>/README.md
workspaces/<scope>/threads/<slug>/artifacts/
```

Other folders can be created lazily when first used:

```text
sessions/
research/
plans/
concepts/
```

Thread README should use YAML frontmatter and generated markers.

### Scope routing

Profile/base is authoritative:

```text
personal profile/base -> workspaces/personal
work/Lunar profile/base -> workspaces/lunar
unknown -> no writes unless explicitly configured
```

Read scope from Pi/nix-agent environment when available:

```text
NAX_BASE
NAX_PROFILE
PI_CODING_AGENT_DIR
```

### LifeOS repo resolution

Resolution order:

1. `LIFEOS_REPO` env var
2. extension/profile configured default
3. known fallback `/Users/kisw/git/github.com/kirksw/lifeOS`
4. if missing: disable writes and report via `/lifeos status`

### Write/commit policy

Direct writes are allowed. Auto-commit must be optional and disabled by default.

Suggested config:

```ts
{
  autoCommit: false,
  commitMode: "manual" | "session-end" | "capture"
}
```

## Proposed code layout

```text
agents/targets/pi/extensions/lifeos/
  index.ts
  core/
    config.ts
    scope.ts
    repo.ts
    slug.ts
    schema.ts
    store.ts
    routing.ts
    scoring.ts
  commands/
    status.ts
    thread.ts
    capture.ts
    focus.ts
    render.ts
  render/
    markdown.ts
    tracker.ts
    focus.ts
    thread-readme.ts
```

## Implementation phases

### Phase 1: extension skeleton and status

Deliver:

- extension loads in Pi;
- `/lifeos status` reports:
  - resolved LifeOS repo path;
  - resolved scope;
  - workspace path;
  - store path;
  - active thread, if any;
  - write enabled/disabled;
  - git dirty state for `lifeOS` repo.

Validation:

- launch Pi with extension loaded;
- run `/lifeos status` from personal and Lunar contexts;
- verify it refuses ambiguous/unknown scope.

### Phase 2: JSONL store and thread commands

Deliver:

- append/read JSONL helpers;
- basic record IDs and timestamps;
- `/lifeos new-thread <title> --kind <kind>`;
- `/lifeos thread <slug>` to select active thread for current session;
- create thread README skeleton.

Initial thread kinds:

```text
idea | research | project | product | concept | ops
```

Validation:

- create a personal thread;
- verify `threads.jsonl` append;
- verify README generated markers and manual notes section;
- verify no Lunar write from personal profile.

### Phase 3: metrics and focus

Deliver:

- metric records and thread-to-metric `contributes_to` edges;
- minimal focus scoring:
  - impact;
  - confidence;
  - urgency;
  - effort;
  - blockers;
  - salience;
  - manual override;
- `/lifeos focus` prints recommendations.

Initial metric kinds:

```text
quantitative | qualitative | milestone | capability
```

Validation:

- create/link at least one metric;
- blocked thread is deprioritized;
- unblocked high-impact thread ranks higher.

### Phase 4: render markdown views

Deliver:

- update generated sections only;
- render workspace `TRACKER.md`;
- render optional `FOCUS.md`;
- render thread README generated sections.

Validation:

- human-authored text outside markers preserved;
- duplicate/missing generated marker behavior is safe;
- generated tracker groups active/blocked threads by stage/status and shows review queues.

### Phase 5: capture

Deliver:

- `/lifeos capture "text"` writes an explicit candidate or decision;
- `/lifeos capture` creates a candidate extraction request/record for agent-assisted summarization;
- clear facts can be promoted; uncertain facts remain in candidates.

Validation:

- explicit capture writes a record linked to active thread;
- no active thread writes to review/inbox candidate state instead of guessing.

### Phase 6: thread routing and context injection

Deliver after manual commands are stable.

Routing precedence:

1. explicit active thread;
2. LifeOS index lookup;
3. associativity match;
4. inbox fallback.

Inject only when confidence is high:

- explicit thread selected;
- repo default thread matches;
- repo related thread plus prompt terms gives high confidence.

Injection should happen before agent/model turn and stay small, focused on:

- active thread;
- status/stage;
- next action;
- open blockers;
- recent decisions;
- related threads by name/reason.

### Phase 7: evolve flow

Deliver after records/rendering have enough usage evidence.

`/lifeos evolve` analyzes:

- LifeOS records;
- markdown artifacts;
- recent raw Pi/agent sessions as evidence only.

It writes ranked recommendations and proposal artifacts. Adoption requires `/grill-me` review.

## Risks and guardrails

- **Overbuilt ontology:** keep schema flexible; stage is a freeform string with suggestions.
- **Wrong routing:** low confidence must not inject or write canonical truth; use inbox/candidates.
- **Personal/work leakage:** use physical store separation and profile-authoritative routing.
- **Markdown clobbering:** only edit generated marker blocks; preserve manual sections.
- **Noisy capture:** queue uncertain candidates instead of writing canonical records.
- **Fragmentation:** `FOCUS.md` is optional; collapse into tracker if it becomes too much.

## Out of scope for v0

- standalone CLI;
- generic analytics dashboard;
- universal MCP/tool-output interception;
- strict lifecycle validation;
- automatic schema evolution;
- GlueSQL integration unless JSONL in-memory queries become painful.

## Completion summary

### What changed

- Added `agents/targets/pi/extensions/lifeos/` with `/lifeos status`, `/lifeos new-thread`, `/lifeos thread`, `/lifeos capture`, `/lifeos focus`, and `/lifeos render`.
- Added git-backed JSONL store helpers for the initial `.lifeos/db/*.jsonl` files.
- Added thread README skeleton generation with YAML frontmatter and protected generated markers.
- Added generated `TRACKER.md`, `FOCUS.md`, and thread README rendering that preserves manual content and refuses duplicate marker clobbering.
- Added scope/repo resolution with writes disabled when the LifeOS repo, workspace, or profile-derived scope cannot be resolved.
- Added path-safety checks so editable JSONL thread paths cannot render outside the selected workspace.

### What was tested

```sh
./scripts/check-structure.sh
nix flake check --no-build
PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/lifeos/index.ts --mode json -p --no-tools --no-session '/lifeos status'
PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/lifeos/index.ts --mode json -p --no-tools --no-session '/lifeos new-thread Test Extension Thread --kind project'
PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/lifeos/index.ts --mode json -p --no-tools --no-session '/lifeos capture "candidate text"'
PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/lifeos/index.ts --mode json -p --no-tools --no-session '/lifeos render'
```

Additional smoke coverage verified path-traversal render records are refused.

### Follow-up

- Metric/link creation commands, thread routing/context injection, and `/lifeos evolve` are tracked in `docs/BACKLOG.md`.
