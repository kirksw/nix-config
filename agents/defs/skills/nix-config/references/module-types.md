# Module Types

This repository configures Pi only. Two module types remain.

1. Skill: a reusable workflow or domain guide exposed through the skill system
2. Profile: a runtime context that selects skills and model tiers, inside a base that owns credentials, authentication, and sessions

When the user is unsure, ask what outcome they want:

- reusable guidance or workflow: skill
- different active skills or model tiers for a scope: profile

Do not offer agent, lifecycle-hook, or preset definitions as skill/profile module types.
MCP servers are configured separately in `agents/base-settings.nix`; dedicated CLI skills use
the base `mcporter.json` where applicable.
