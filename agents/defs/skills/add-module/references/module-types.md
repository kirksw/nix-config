# Module Types

This repository configures Pi only. Two module types remain.

1. Skill: a reusable workflow or domain guide exposed through the skill system
2. Profile: a runtime context that selects skills and model tiers, inside a base that owns credentials, authentication, and sessions

When the user is unsure, ask what outcome they want:

- reusable guidance or workflow: skill
- different active skills or model tiers for a scope: profile

Agents, MCP server definitions, lifecycle hooks, and preset bundles were removed together with
the external `nix-agents` generator. Do not offer them. MCP access is exposed through generated
CLI skills that read the base `mcporter.json`.
