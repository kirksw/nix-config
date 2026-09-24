# Model benchmark reference

**Status:** Active
**Last verified:** 2026-09-22
**Profile:** `personal-default`
**Configuration:** [`agents/pi-profiles.nix`](../../agents/pi-profiles.nix)

Use this reference to compare configured models on the benchmark and operational dimensions requested for tier decisions.
Values are specific to the Artificial Analysis model variants and harness settings listed; they may not match a provider's served model alias or runtime configuration.

## Assessment dimensions

| Category | Dimension | Interpretation |
| --- | --- | --- |
| Capability | APEX-Agents-AA | Long-horizon, cross-application professional tasks. |
| Capability | AutomationBench-AA | Agentic SaaS workflow tasks. |
| Capability | AA-Omniscience | Knowledge reliability and hallucination; higher is better. |
| Capability | DeepSWE | End-to-end software engineering tasks. |
| Capability | Terminal-Bench 4.0 | Agentic terminal tasks. |
| Cost | Cost per task | Artificial Analysis's reported cost per benchmark task; benchmark/harness-specific. |
| Speed | Output tokens/s | Post-first-token generation speed; provider and configuration matter. |

## Current model comparison

Scores are transcribed only when a source explicitly reported them for a matching model variant. `—` means not verified, not zero or a failed result. Provisional rows cover the configured personal tiers; work-only models are included where they are distinct.

| Model (configured identifier) | AA variant | APEX-Agents-AA | AutomationBench-AA | AA-Omniscience | DeepSWE | Terminal-Bench 4.0 | Cost/task (USD) | Output tok/s |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `litellm/openai/gpt-6-astra` | GPT-6 Astra (max) | — | 68.5% | 44 | 68%† | 59.1%‡ | $2.57* | 87.5 |
| `litellm/openai/gpt-6-sol` / `openai/gpt-6-sol` | GPT-6 Sol (max) | — | — | — | — | — | $1.06* | — |
| `litellm/openai/gpt-6-luna` / `openai/gpt-6-luna` | GPT-6 Luna (max) | — | — | — | — | — | $0.07* | — |
| `litellm/glm-5.3` | GLM-5.3 (max) | — | — | — | 61%† | — | $2.01* | 72.1 |
| `litellm/glm-5.3-flash` | GLM-5.3 Flash | — | — | — | — | — | $0.25* | 107.0 |
| `litellm/deepseek-v4-pro` | DeepSeek V4 Pro 0813 (Reasoning, Max Effort) | — | — | -10 | 8%§ | — | $0.67* | 88.8 |
| `litellm/deepseek-flash` | DeepSeek V4 Flash 0731 (Reasoning, Max Effort) | — | — | -23 | — | — | $0.11* | 129.9 |
| `amazon-bedrock/eu.anthropic.claude-opus-5-5` | Claude Opus 5.5 (Adaptive Reasoning, Max Effort, Default Fallback) | — | — | — | — | — | $5.98* | — |

\* Cost per Artificial Analysis Intelligence Index task, not cost per one of the selected individual benchmark tasks. Included as an operational reference only; do not compare it as if it were the same cost measure as every benchmark-specific task.

† Artificial Analysis Coding Agent Index harness comparison: Codex GPT-6 Astra (max) vs Opencode GLM-5.3, reported DeepSWE v1.1 Pass@1 of 68% and 61%, respectively. These are model-plus-harness results, not base-model-only scores.

‡ Artificial Analysis reports GPT-6 Astra (max) Terminal-Bench 4.0 at 59.1% on its model leaderboard. Its Coding Agent Index Codex comparison reports 56% under that harness; do not treat those results as directly interchangeable.

§ DeepSeek V4 Pro 0813 is listed at 8% on the DeepSWE v1.1 leaderboard snapshot. The exact harness/effort configuration should be checked before comparing with the Coding Agent Index results.

The available DeepSeek article reports different Index scores and task costs for older/currently distinct model snapshots in different places. This table avoids combining those values and records only the model-page values explicitly surfaced for Pro 0813 and Flash 0731. The configured LiteLLM aliases have not been confirmed to target those exact snapshots.

## Evidence and gaps

- DeepSeek V4 Pro 0813: Artificial Analysis reports AA-Omniscience -10, $0.67 per Intelligence Index task, and 88.8 output tokens/s.
- DeepSeek V4 Flash 0731: Artificial Analysis reports AA-Omniscience -23, $0.11 per Intelligence Index task, and 129.9 output tokens/s.
- GPT-6 Astra (max): Artificial Analysis reports AutomationBench-AA 68.5%, AA-Omniscience 44, Terminal-Bench 4.0 59.1%, cost per Intelligence Index task $2.57, and output speed 87.5 tokens/s.
- GPT-6 Sol (max): cost per Intelligence Index task $1.06; AA currently reports no output-speed datapoint.
- GPT-6 Luna (max): cost per Intelligence Index task $0.07; AA currently reports no output-speed datapoint.
- GLM-5.3 (max): cost per Intelligence Index task $2.01 and output speed 72.1 tokens/s. GLM-5.3 Flash: $0.25 and 107.0 tokens/s.
- Claude Opus 5.5 (max with fallback): cost per Intelligence Index task $5.98; AA currently reports no output-speed datapoint.
- DeepSeek V4 Pro 0813: AA reports AA-Omniscience -10, $0.67 per Intelligence Index task, and 88.8 output tokens/s; DeepSWE v1.1 reports 8% on a leaderboard snapshot.
- DeepSeek V4 Flash 0731: AA reports AA-Omniscience -23, $0.11 per Intelligence Index task, and 129.9 output tokens/s.
- APEX-Agents-AA leaderboard currently lists only eight agents; it does not give scores for all these model identifiers. For every unlisted model/metric, the value stays unverified, not zero.
- APEX-Agents-AA evaluates cross-application professional tasks; AutomationBench-AA evaluates agentic SaaS workflows; DeepSWE and Terminal-Bench scores depend on the evaluated agent harness, not only the base model.
- Compare benchmark results only when model snapshots, reasoning effort, agent harness, and provider conditions match. Keep unknown values as `—` rather than estimating them.

## Sources

- [Artificial Analysis APEX-Agents-AA](https://artificialanalysis.ai/evaluations/apex-agents-aa)
- [Artificial Analysis AutomationBench-AA](https://artificialanalysis.ai/evaluations/automationbench-aa)
- [Artificial Analysis Terminal-Bench 4.0](https://artificialanalysis.ai/evaluations/terminalbench-4-0)
- [DeepSeek V4 Pro 0813 model page](https://artificialanalysis.ai/models/deepseek-v4-pro)
- [DeepSeek V4 Flash 0731 model page](https://artificialanalysis.ai/models/deepseek-v4-flash)
- [Artificial Analysis GPT-6 Astra](https://artificialanalysis.ai/models/gpt-6-astra)
- [Artificial Analysis DeepSeek V4 Pro vs Flash comparison](https://artificialanalysis.ai/models/comparisons/deepseek-v4-pro-vs-deepseek-v4-flash)
- [Artificial Analysis GPT-6 Sol](https://artificialanalysis.ai/models/gpt-6-sol)
- [Artificial Analysis GPT-6 Luna](https://artificialanalysis.ai/models/gpt-6-luna)
- [Artificial Analysis GLM-5.3](https://artificialanalysis.ai/models/glm-5-3)
- [Artificial Analysis GLM-5.3 Flash](https://artificialanalysis.ai/models/glm-5-3-flash)
- [Artificial Analysis Claude Opus 5.5](https://artificialanalysis.ai/models/claude-opus-5-5)
- [Artificial Analysis coding-agent comparison: Codex vs Opencode](https://artificialanalysis.ai/agents/coding-agents/comparisons/codex-vs-opencode)
- [Artificial Analysis DeepSWE v1.1 leaderboard](https://artificialanalysis.ai/agents/coding-agents)
- [Artificial Analysis coding agents methodology](https://artificialanalysis.ai/methodology/coding-agents-benchmarking)
