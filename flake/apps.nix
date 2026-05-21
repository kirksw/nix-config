{
  nixpkgs,
  mylibs,
  inputs,
}:
{
  system,
  appCommands ? [
    "build"
    "switch"
    "rollback"
  ],
  packageNames,
  packages,
}:
let
  pkgs = import nixpkgs { inherit system; };
  updateCommandFor =
    name:
    let
      pkg = packages.${name};
      passthru = pkg.passthru or { };
    in
    if passthru ? updateScript then
      toString passthru.updateScript
    else
      "echo 'No updateScript for ${name}'";

  updateAllPackages = pkgs.writeShellScriptBin "update-packages" ''
    set -euo pipefail
    export repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || ${pkgs.coreutils}/bin/pwd)"
    cd "$repo_root"
    echo "Updating all packages..."
    ${builtins.concatStringsSep "\n" (
      map (name: ''
        echo "-> Updating ${name}..."
        ${updateCommandFor name}
      '') packageNames
    )}
    echo "Done!"
  '';

  # Sync backend-engineering-practices skills to work profile directories.
  # nix-agents wrappers handle the rest (agent config sync happens at wrapper runtime).
  syncSkills = pkgs.writeShellScriptBin "sync-work-skills" ''
    set -euo pipefail

    sync_tree() {
      source_dir="$1"
      target_dir="$2"
      ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
      ${pkgs.coreutils}/bin/chmod -R u+w "$target_dir" 2>/dev/null || true
      ${pkgs.coreutils}/bin/rm -rf "$target_dir"/* "$target_dir"/.[!.]* "$target_dir"/..?* 2>/dev/null || true
      ${pkgs.coreutils}/bin/cp -R "$source_dir"/. "$target_dir"/
    }

    source_skills="${inputs.backend-engineering-practices}/skills"

    if [ ! -d "$source_skills" ]; then
      echo "No backend-engineering-practices skills found at $source_skills"
      exit 0
    fi

    # nix-agents wrappers now use bases/<base>/profiles/<profile>/ layout
    # The wrappers copy config at runtime, but work-specific skill overlays
    # need to be available in the profile dirs after sync-agents runs.
    echo "Syncing backend-engineering-practices skills to work profiles..."
    CONFIG_BASE="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents"

    for target in opencode claude codex pi; do
      target_dir="$CONFIG_BASE/$target/bases/work/profiles/work-default/skills"
      if [ -d "$target_dir" ]; then
        ${pkgs.coreutils}/bin/cp -R "$source_skills"/. "$target_dir/"
        echo "  -> $target_dir"
      fi
    done

    echo "Done!"
  '';
in
(builtins.listToAttrs (
  map (name: {
    inherit name;
    value = mylibs.app.mkApp name system;
  }) appCommands
))
// {
  update-packages = {
    type = "app";
    program = "${updateAllPackages}/bin/update-packages";
    meta = {
      description = "Run update scripts for custom packages in this repository.";
    };
  };

  sync-work-skills = {
    type = "app";
    program = "${syncSkills}/bin/sync-work-skills";
    meta = {
      description = "Sync backend-engineering-practices skills to work profile directories.";
    };
  };

  install-hooks = {
    type = "app";
    program = "${pkgs.writeShellScript "install-hooks" ''
      set -euo pipefail
      echo "Installing git pre-commit hooks..."
      cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel)"
      ${pkgs.nix}/bin/nix develop --command bash -c "pre-commit install"
      echo "Hooks installed successfully!"
    ''}";
    meta = {
      description = "Install git pre-commit hooks for this repository.";
    };
  };
}
