# feat-assistant-github-app-helper

> Add a local helper for creating repository-scoped assistant GitHub Apps.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Assistant microVMs need narrowly scoped GitHub App credentials for their matching
knowledge-base repositories. Creating each app manually is repetitive and risks
inconsistent permissions or saved secret locations.

## Plan

### Scope

- `scripts/assistant-github-apps.py`
- `.gitignore`

### Approach

1. Add a local Python helper that serves GitHub App manifests for the personal,
   household, and work assistant apps.
2. Convert returned GitHub manifest codes through the GitHub API and store
   generated app secrets outside the repo by default.
3. Ignore Python bytecode/cache output so local helper runs do not dirty the
   worktree.

### Risks

- GitHub App installation IDs still need to be recorded manually after browser
  installation.
- The helper intentionally writes private keys outside the repo, but generated
  secret files must still not be copied into source control.

## Testing

Commands run to validate:

```sh
python3 -c 'import ast, pathlib; ast.parse(pathlib.Path("scripts/assistant-github-apps.py").read_text())'
python3 scripts/assistant-github-apps.py --help
```

## Summary

### What changed

- Added `scripts/assistant-github-apps.py`.
- Added Python cache patterns to `.gitignore`.

### What was tested

- Parsed the helper script with Python `ast`.
- Checked the helper CLI help output.

### Follow-up

- None.
