---
name: hubble-mcp
description: Use Hubble MCPorter CLI to investigate Airflow DAGs and SYNQ entities, lineage, freshness, quality, executions, and incidents.
---

# Hubble MCP

Run the generated `hubble-mcp` CLI through Context Mode and the shared bounded runner:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" hubble-mcp synq-search-entities --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" hubble-mcp synq-entity-health --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" hubble-mcp airflow-dag-runs --help
```

Resolve the exact entity or DAG before requesting lineage, executions, task instances, quality, freshness, or incidents.
Bound lineage direction and depth, execution windows, and result counts.
Report identifiers, timestamps, environment, evidence, and time zone separately from hypotheses.
Follow the `work-mcp` authentication guidance when Hubble OAuth is unavailable.
