---
name: sourcegraph
description: Use Sourcegraph MCPorter CLI for remote repository discovery, code and commit search, diffs, and targeted file reading across work repositories.
---

# Sourcegraph

Run the generated `sourcegraph` CLI through Context Mode and the shared bounded runner:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" sourcegraph list-repos --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" sourcegraph keyword-search --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" sourcegraph code-finder --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" sourcegraph read-file --help
```

Use Sourcegraph when the answer may span remote work repositories or repository history; use local search tools for the current checkout.
Start with repository scope plus a symbol, literal, path, author, or time range.
Use `keyword-search` for exact evidence, `nls-search` or `code-finder` for discovery, and `commit-search` or `diff-search` for history.
Read only the files or diffs needed to verify the result, and cite repository, revision, and path.
Follow the `work-mcp` authentication guidance when Sourcegraph OAuth is unavailable.
