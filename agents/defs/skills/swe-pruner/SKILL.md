---
name: swe-pruner
description: Use SWE-Pruner MCPorter CLI to search or read large code inputs with a focused question and bounded context.
---

# SWE-Pruner

Run the generated `swe-pruner` CLI through Context Mode and the shared bounded runner:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" swe-pruner search-pruned --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" swe-pruner read-pruned --help
```

Use `search-pruned` to locate relevant code and `read-pruned` for large files when ordinary local reads would produce excessive context.
Provide a concrete focus question so pruning retains the evidence needed for the task.
If pruning omits required context, narrow the question or use the ordinary local file tools for an exact read.
Do not use SWE-Pruner as a substitute for Sourcegraph when the search must span remote repositories.
