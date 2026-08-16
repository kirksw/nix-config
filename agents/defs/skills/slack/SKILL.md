---
name: slack
description: Use Slack MCPorter CLI to search, read, triage, and summarize conversations or perform explicitly confirmed Slack actions.
---

# Slack

Run the generated `slack` CLI through Context Mode and the shared bounded runner:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" slack slack-search-messages --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" slack slack-get-thread --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" slack slack-catch-me-up --help
```

Constrain searches by channel, participant, topic, and time range before expanding a thread or conversation.
Resolve users and channels only as needed, and do not expose unrelated private-message content.
Treat send, reaction, mark, refresh, triage, and workflow-save commands as mutations and follow the confirmation control in the `work-mcp` skill.
