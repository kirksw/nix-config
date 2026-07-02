# agenticOS Factory Profiles

lifeOS `scripts/agentic-factory` maps profiles directly to these Pi wrappers:

- `--profile home-factory` → `pi-home-factory`
- `--profile work-factory` → `pi-work-factory`

Both wrappers run Pi in the caller's current repo. lifeOS passes the repo-local extension with `--extension .agents/extensions/agentic-os-factory.mjs`; the wrappers pass explicit `--extension` args through unchanged.

The Nix profiles keep only the factory Pi packages: `pi-subagents`, `pi-permission-system`, and `pi-web-access`. Home uses personal model/auth defaults; work uses work model/auth defaults.
