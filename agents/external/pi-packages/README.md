# Pi Packages

This directory owns Pi package catalog integration for this repo.

Pi packages are installable Pi resources referenced from `settings.json`
entries such as `npm:pi-subagents@0.28.0` or pinned git refs such as
`git:github.com/user/repo@<commit>`. The package manifest then declares its
own extensions, skills, prompts, and themes.

Policy:

- Keep package selection and pinned refs in `registry.nix`.
- Pin explicit npm versions or git commits in generated settings.
- Prefer package names from <https://pi.dev/packages> when available.
- Keep local custom Pi assets under `agents/targets/pi/`.
- Do not vendor package contents into this repo unless a package needs a local
  patch.
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

   Git-backed packages can use a pinned `ref` instead:

   ```nix
   ponytail = {
     enabled = true;
     ref = "git:github.com/DietrichGebert/ponytail@<commit>";
     version = "<commit>";
     types = [
       "extension"
       "skill"
     ];
     source = "https://github.com/DietrichGebert/ponytail";
   };
   ```

3. Run:

   ```sh
   nix flake check --no-build
   nix run .#sync-agents
   ```

If a catalog package needs local patches, add a separate patched package path
instead of overloading this registry.
