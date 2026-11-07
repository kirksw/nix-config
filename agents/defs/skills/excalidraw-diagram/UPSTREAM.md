# Vendored Source

- Project: `coleam00/excalidraw-diagram-skill`
- Revision: `8646fcc9f74f38539c6cdb4c969723336a96ddcd`
- Original files: `SKILL.md`, `README.md`, and `references/`
- Changes: use `$PI_CODING_AGENT_DIR/skills/excalidraw-diagram` instead of `.claude/skills/excalidraw-diagram` in setup/render instructions; remove project-local installation steps.
- License: no license file or explicit grant in the upstream repository at this revision; included at the user's request.

The Playwright renderer loads `@excalidraw/excalidraw` from `esm.sh` at runtime and needs network access.
Run `uv sync` and install Playwright Chromium in the skill's `references/` directory before using the renderer; these dependencies are not included in the vendored copy.
