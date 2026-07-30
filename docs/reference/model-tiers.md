# Model tier reference

**Status:** Active  
**Last verified:** 2026-07-24  
**Profile:** `personal-default`  
**Configuration:** [`agents/presets/profiles.nix`](../../agents/presets/profiles.nix)

This document tracks the configured model chains across four dimensions:

- **Intelligence (generic):** Artificial Analysis Intelligence Index, where available.
- **Specialized intelligence:** selected Artificial Analysis benchmark dimensions by task area.
- **Cost:** USD per 1M input/output tokens.
- **Speed:** Artificial Analysis output tokens per second (post-first-token decode throughput).

Values are snapshots, not guarantees. Provider, region, queue load, caching, context length, and reasoning effort affect actual results.

## Personal tiers

| Tier | Model | Intelligence | Cost (input / output) | Speed | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| S | `openai-codex/gpt-5.6-sol` | 59 | $5 / $30 | 63.3 tok/s | AA model page |
| A | `openai-codex/gpt-5.6-terra` | 55 | $2.50 / $15 | 132.0 tok/s | AA model page |
| A | `openai-codex/gpt-5.5` | — | — | — | Not separately verified on AA |
| A | `zai/glm-5.2` | 51 | $1.40 / $4.40 | 179.4 tok/s | Provider-dependent speed |
| B | `openai-codex/gpt-5.6-luna` | 51 | $1 / $6 | 172.5 tok/s | AA model page |
| B | `openai-codex/gpt-5.4` | — | — | — | Not separately verified on AA |
| C | `openai-codex/gpt-5.4-mini` | 40 | $0.75 / $4.50 | 169.7 tok/s | AA model page |
| C | `minimax/minimax-m3` | 44 | $0.30 / $1.20 | 99.4 tok/s | Provider-dependent speed |
| D | `openai-codex/gpt-5.3-codex-spark` | 44* | $1.75 / $14* | 127.8 tok/s* | *Proxy: AA's `gpt-5.3-codex` xhigh page |
| D | `minimax/minimax-m2.7-highspeed` | — | — | — | Not separately verified on AA |
| D | `zai/glm-5-turbo` | 38 | — | — | AA reports no benchmarked providers |
| E | `openai-codex/gpt-5.4-nano` | 38 | $0.20 / $1.25 | 151.0 tok/s | AA model page |

`—` means the value has not been verified from Artificial Analysis. It is preferable to leave a value unknown than to infer it from a differently named model or provider.

## Specialized intelligence (task-focused benchmarks)

A single Intelligence Index value is an aggregate and does not capture task-specific strengths. Use specialized scores when a workload has a clear benchmark fit.

### Benchmark task areas

| Task area | Included AA benchmark dimensions |
| --- | --- |
| General capability checks | GDPval-AA v2, AA-LCR |
| Financial and banking workflows | τ³-Banking |
| Terminal / automation workflows | Terminal-Bench v2.1 |
| Scientific and programming tasks | SciCode |
| Broad exam-style reasoning | Humanity's Last Exam, GPQA Diamond |
| Critique / robustness | CritPt |
| World knowledge breadth | AA-Omniscience |

### Specialized benchmark data schema (per-model)

| Model | GDPval-AA v2 | τ³-Banking | Terminal-Bench v2.1 | SciCode | Humanity's Last Exam | GPQA Diamond | CritPt | AA-Omniscience | AA-LCR |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `openai-codex/gpt-5.6-sol` | — | — | — | — | — | — | — | — | — |
| `openai-codex/gpt-5.6-terra` | — | — | — | — | — | — | — | — | — |
| `openai-codex/gpt-5.5` | — | — | — | — | — | — | — | — | — |
| `zai/glm-5.2` | — | — | — | — | — | — | — | — | — |
| `openai-codex/gpt-5.6-luna` | — | — | — | — | — | — | — | — | — |
| `openai-codex/gpt-5.4` | — | — | — | — | — | — | — | — | — |
| `openai-codex/gpt-5.4-mini` | — | — | — | — | — | — | — | — | — |
| `minimax/minimax-m3` | — | — | — | — | — | — | — | — | — |
| `openai-codex/gpt-5.3-codex-spark` | — | — | — | — | — | — | — | — | — |
| `minimax/minimax-m2.7-highspeed` | — | — | — | — | — | — | — | — | — |
| `zai/glm-5-turbo` | — | — | — | — | — | — | — | — | — |
| `openai-codex/gpt-5.4-nano` | — | — | — | — | — | — | — | — | — |

### Routing note

- Route by benchmark first when a task maps clearly to one of the dimensions above.
- Prefer the model with the highest verified score for that dimension, then apply existing cost/speed policy for tie-breaks.
- If a required benchmark value is missing (`—`), keep using the generic tier policy and revalidate with targeted tests before making routing changes.

## Sources

- [Artificial Analysis model leaderboard](https://artificialanalysis.ai/models)
- [Intelligence Index methodology](https://artificialanalysis.ai/methodology/intelligence-benchmarking)
- [Performance methodology](https://artificialanalysis.ai/methodology/performance-benchmarking)
- [GPT-5.6 Sol](https://artificialanalysis.ai/models/gpt-5-6-sol)
- [GPT-5.6 Terra](https://artificialanalysis.ai/models/gpt-5-6-terra)
- [GPT-5.6 Luna](https://artificialanalysis.ai/models/gpt-5-6-luna)
- [GPT-5.4 mini](https://artificialanalysis.ai/models/gpt-5-4-mini)
- [GPT-5.4 nano](https://artificialanalysis.ai/models/gpt-5-4-nano)
- [GPT-5.3 Codex](https://artificialanalysis.ai/models/gpt-5-3-codex)
- [GLM-5.2](https://artificialanalysis.ai/models/glm-5-2)
- [GLM-5-Turbo](https://artificialanalysis.ai/models/glm-5-turbo)
- [MiniMax-M3](https://artificialanalysis.ai/models/minimax-m3)

## Maintenance

Recheck this document when changing `tierMapping` or before making a cost/performance decision. Update `Last verified` and retain the model's Artificial Analysis link when refreshing values.
