{
  nixpkgs,
  mylibs,
  inputs,
  self,
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
  lib = nixpkgs.lib;
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

  localAgents = import ../agents { inherit pkgs; };
  localAgentsSrc = ../agents;
  agentInputs = inputs // {
    inherit self;
  };
  nixAgentsLib = inputs.nix-agents.lib.${system};
  agentModulesFor = target: if target == "pi" then localAgents.piModules else localAgents.defaultModules;

  profileMetaFor =
    target:
    nixAgentsLib.mkProfileMeta {
      inherit pkgs target;
      modules = agentModulesFor target;
      inputs = agentInputs;
      src = localAgentsSrc;
    };

  syncProfileCommands =
    target:
    let
      profileMeta = profileMetaFor target;
      targetSpec =
        {
          opencode = {
            dirs = [
              "agents"
              "skills"
            ];
            files = [
              "hook-manifest"
              "skill-versions.json"
              "AGENTS.md"
              "opencode.json"
            ];
          };
          claude = {
            dirs = [
              "agents"
              "skills"
            ];
            files = [
              "hook-manifest"
              "skill-versions.json"
              "CLAUDE.md"
              "settings.json"
              ".mcp.json"
            ];
          };
          codex = {
            dirs = [
              "agents"
              "skills"
            ];
            files = [
              "hook-manifest"
              "skill-versions.json"
              "AGENTS.md"
              "mcp.nix.toml"
            ];
          };
          pi = {
            dirs = [
              "agents"
              "skills"
              "extensions"
              "prompts"
            ];
            files = [
              "hook-manifest"
              "skill-versions.json"
              "AGENTS.md"
            ];
          };
        }
        .${target};
      syncProfile =
        profileName: meta:
        let
          profileDir = "$CONFIG_BASE/${target}/bases/${meta.base}/profiles/${profileName}";
          settingsDir = "$CONFIG_BASE/${target}/bases/${meta.base}/settings";
          dirCommands = lib.concatMapStringsSep "\n" (dir: ''
            sync_tree "${meta.storePath}/${dir}" "${profileDir}/${dir}"
          '') targetSpec.dirs;
          fileCommands = lib.concatMapStringsSep "\n" (file: ''
            sync_file "${meta.storePath}/${file}" "${profileDir}/${file}"
          '') targetSpec.files;
          postCommands =
            if target == "codex" then
              ''
                link_base_settings_except_config_toml "${settingsDir}" "${profileDir}"
                merge_codex_config "${settingsDir}/config.toml" "${profileDir}/mcp.nix.toml" "${profileDir}/config.toml"
              ''
            else
              ''
                link_base_settings "${settingsDir}" "${profileDir}"
              '';
        in
        ''
          echo "Syncing ${target}/${meta.base}/${profileName}"
          mkdir_p "${profileDir}"
          ${dirCommands}
          ${fileCommands}
          ${postCommands}
        '';
    in
    lib.concatStringsSep "\n" (lib.mapAttrsToList syncProfile profileMeta);

  allSyncCommands = lib.concatStringsSep "\n" (
    map syncProfileCommands [
      "opencode"
      "claude"
      "codex"
      "pi"
    ]
  );

  syncAgents = pkgs.writeShellScriptBin "sync-agents" ''
    set -euo pipefail

    DRY_RUN=0
    case "''${1:-}" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      -h|--help)
        cat <<'EOF'
    Usage: sync-agents [--dry-run]

    Sync generated nix-agents assets from this flake into ~/.config/nix-agents
    without running darwin-rebuild switch.
    EOF
        exit 0
        ;;
    esac

    if [ "$#" -gt 0 ]; then
      echo "sync-agents: unexpected argument: $1" >&2
      exit 2
    fi

    CONFIG_BASE="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents"

    run() {
      if [ "$DRY_RUN" -eq 1 ]; then
        printf 'DRY-RUN '
        printf '%q ' "$@"
        printf '\n'
      else
        "$@"
      fi
    }

    mkdir_p() {
      run ${pkgs.coreutils}/bin/mkdir -p "$1"
    }

    sync_tree() {
      source_dir="$1"
      target_dir="$2"
      if [ -e "$target_dir" ]; then
        run ${pkgs.coreutils}/bin/chmod -R u+w "$target_dir" 2>/dev/null || true
      fi
      run ${pkgs.coreutils}/bin/rm -rf "$target_dir"
      if [ -d "$source_dir" ]; then
        run ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
        run ${pkgs.coreutils}/bin/cp -R "$source_dir"/. "$target_dir"/
        run ${pkgs.coreutils}/bin/chmod -R u+w "$target_dir"
      fi
    }

    sync_file() {
      source_file="$1"
      target_file="$2"
      run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target_file")"
      if [ -e "$target_file" ]; then
        run ${pkgs.coreutils}/bin/chmod u+w "$target_file" 2>/dev/null || true
      fi
      run ${pkgs.coreutils}/bin/rm -rf "$target_file"
      if [ -f "$source_file" ]; then
        run ${pkgs.coreutils}/bin/cp "$source_file" "$target_file"
        run ${pkgs.coreutils}/bin/chmod u+w "$target_file"
      fi
    }

    link_base_settings() {
      settings_dir="$1"
      profile_dir="$2"
      if [ -d "$settings_dir" ]; then
        for f in "$settings_dir"/*; do
          [ -f "$f" ] || continue
          name="''${f##*/}"
          [ "$name" = "env" ] && continue
          run ${pkgs.coreutils}/bin/ln -sfn "$f" "$profile_dir/$name" 2>/dev/null || true
        done
      fi
    }

    link_base_settings_except_config_toml() {
      settings_dir="$1"
      profile_dir="$2"
      if [ -d "$settings_dir" ]; then
        for f in "$settings_dir"/*; do
          [ -f "$f" ] || continue
          name="''${f##*/}"
          [ "$name" = "env" ] && continue
          [ "$name" = "config.toml" ] && continue
          run ${pkgs.coreutils}/bin/ln -sfn "$f" "$profile_dir/$name" 2>/dev/null || true
        done
      fi
    }

    merge_codex_config() {
      user_config="$1"
      nix_mcp_config="$2"
      target_config="$3"

      if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY-RUN merge_codex_config $user_config $nix_mcp_config $target_config"
        return 0
      fi

      rm -f "$target_config"
      if [ -f "$user_config" ]; then
        cat "$user_config" >> "$target_config"
      fi
      if [ -s "$nix_mcp_config" ]; then
        if [ -s "$target_config" ]; then
          printf '\n' >> "$target_config"
        fi
        cat "$nix_mcp_config" >> "$target_config"
      fi
      if [ -e "$target_config" ]; then
        chmod u+w "$target_config"
      fi
    }

    ${allSyncCommands}

    source_skills="${inputs.backend-engineering-practices}/skills"
    if [ -d "$source_skills" ]; then
      echo "Syncing backend-engineering-practices skills to work profiles"
      for target in opencode claude codex pi; do
        target_dir="$CONFIG_BASE/$target/bases/work/profiles/work-default/skills"
        if [ -d "$target_dir" ]; then
          run ${pkgs.coreutils}/bin/cp -R "$source_skills"/. "$target_dir/"
          echo "  -> $target_dir"
        fi
      done
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
      echo "Dry run complete. No files were changed."
    else
      echo "Agent config sync complete. Restart agent sessions to pick up changes."
      echo "Note: pre-syncMode wrappers may resync their embedded generation on launch until the next Darwin switch."
    fi
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

  sync-agents = {
    type = "app";
    program = "${syncAgents}/bin/sync-agents";
    meta = {
      description = "Sync generated nix-agents assets to local profile directories without a system switch.";
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
