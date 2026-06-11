# Pi Packages

This directory owns Pi package catalog integration for this repo.

Pi packages are npm-published resources installed by Pi from `settings.json`
entries such as `npm:pi-subagents@0.28.0`. The package manifest then declares
its own extensions, skills, prompts, and themes.

Policy:

- Keep package selection and versions in `registry.nix`.
- Pin explicit npm versions in generated settings.
- Use package names from <https://pi.dev/packages>.
- Keep local custom Pi assets under `agents/targets/pi/`.
- Do not vendor npm package contents into this repo unless a package needs a
  local patch.
- Do not fetch Git repositories from wrappers or activation scripts.

To add or update a package:

1. Look up the package at <https://pi.dev/packages>.
2. Add or edit its `registry.nix` entry:

   ```nix
   "pi-subagents" = {
     enabled = true;
     npmName = "pi-subagents";
     version = "0.28.0";
     types = [
       "extension"
       "skill"
       "prompt"
     ];
     source = "https://pi.dev/packages/pi-subagents";
   };
   ```

3. Run:

   ```sh
   nix flake check --no-build
   nix run .#sync-agents
   ```

If a catalog package needs local patches, add a separate patched package path
instead of overloading this registry.
