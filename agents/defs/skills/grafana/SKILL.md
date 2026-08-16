---
name: grafana
description: Use Grafana MCPorter CLI for dashboards, Prometheus metrics, Pyroscope profiles, annotations, datasource health, and alerting investigations.
---

# Grafana

Run Grafana through Context Mode and the shared bounded runner.
Grafana currently uses MCPorter's typed-client fallback, so pass one JSON argument to each method:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" grafana help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" grafana search_dashboards '{"query":"service-name"}'
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" grafana query_prometheus '{"datasourceUid":"<uid>","endTime":"now","expr":"up","startTime":"now-15m"}'
```

Use `help` to list generated methods and inspect `generated/grafana-client.d.ts` only when exact parameters are unknown.
Start with a named service, the shortest useful time window, and one signal.
Separate timestamps, scope, evidence, and time zone from hypotheses.
Treat alert-routing and alert-rule changes as mutations and follow the confirmation control in the `work-mcp` skill.
