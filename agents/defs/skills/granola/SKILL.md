---
name: granola
description: Use Granola MCPorter CLI to find meetings, notes, and transcripts or answer questions grounded in specific meetings.
---

# Granola

Run the generated `granola` CLI through Context Mode and the shared bounded runner:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" granola list-meetings --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" granola query-granola-meetings --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" granola get-meeting-transcript --help
```

Constrain discovery by date, participant, folder, or topic before reading meeting details.
Prefer `query-granola-meetings` for synthesis and use transcripts only when the request requires exact wording or detailed evidence.
Meeting notes and transcripts are private work data; return only the minimum excerpts needed and preserve citation links when available.
Follow the `work-mcp` authentication guidance when Granola OAuth is unavailable.
