# Source Of Truth

## Default Rule

This machine is Nix-oriented. Prefer persistent changes in the declarative source of truth rather than editing generated files in place.

## For Agent Configuration

The primary source repo for this machine's concrete agent configuration is:

- `/Users/kisw/git/github.com/kirksw/nix-config`

When behavior changes should apply to generated agent configs, make the change in the repo:

- `agents/defs/` for agents, skills, MCP servers, and hooks
- `agents/presets/` for import bundles and profile/base setup
- `agents/targets/` for tool-specific bundled assets such as Pi extensions and prompts
- `modules/home/programs/ai-agents.nix` for Home Manager wrapper wiring

Then rebuild or sync rather than hand-editing generated output.

The external `nix-agents` flake is the reusable engine: module schema, evaluation, wrappers,
generators, schemas, and templates. Change that repo only when the framework itself needs to
change, not for local agent roster/profile policy.

## For Broader System Configuration

The main machine-level Nix configuration repo is:

- `/Users/kisw/git/github.com/kirksw/nix-config`

Use the same repo when the requested change is about broader system setup rather than agent behavior, for example:

- packages installed on the machine
- shell or editor configuration managed outside `agents/`
- system services
- Home Manager or nix-darwin style user/system configuration

If a request touches both agent behavior and machine setup, keep concrete configuration in `nix-config` and only change upstream `nix-agents` for reusable engine behavior.

## Generated Output

Treat these as generated artifacts, not the primary place to make lasting edits:

- `~/.config/nix-agents/<tool>/bases/<base>/profiles/<profile>/...`

Those directories are populated by generated configs and sync logic. If you change files there manually, the next sync or rebuild can overwrite them.

## Practical Decision Rule

If the question is:

- "How should this tool behave?" -> change Nix source
- "Which agents/skills/profiles should be active?" -> change Nix source
- "How should this machine be configured?" -> change `/Users/kisw/git/github.com/kirksw/nix-config`
- "Where does this generated file live right now?" -> inspect generated output
- "Why is the active config resolving this way?" -> inspect bases, profiles, path prefixes, and `.nix-agents-profile`

## For Non-Agent Persistent Setup

If a requested change looks like machine setup, package installation, shell behavior, or other recurring configuration, first ask whether there is a Nix-managed source of truth for it instead of editing local runtime state directly.
