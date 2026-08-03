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
    # Keep nested nix-update tools isolated from stale system-only settings.
    export NIX_CONF_DIR="''${TMPDIR:-/tmp}/nix-update-conf"
    ${pkgs.coreutils}/bin/mkdir -p "$NIX_CONF_DIR"
    printf '%s\n' 'experimental-features = nix-command flakes' > "$NIX_CONF_DIR/nix.conf"
    echo "Updating all packages..."
    ${builtins.concatStringsSep "\n" (
      map (name: ''
        echo "-> Updating ${name}..."
        ${updateCommandFor name}
      '') packageNames
    )}
    echo "Done!"
  '';

  # Legacy/manual compatibility helper. The default work profile uses the
  # lunar-skills MCP server so these skills are loaded on demand.
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
  localAgentsSrc =
    pkgs.runCommandLocal "nix-config-agents-src" { } ''
      mkdir -p "$out"
      cp -r ${../agents}/. "$out/"
      chmod -R u+w "$out"
    '';
  piCommonChainsSrc = ../agents/targets/pi/chains/common;
  agentInputs = inputs // {
    inherit self;
  };
  agentBaseSettings = import ../agents/base-settings.nix {
    inherit
      self
      lib
      system
      ;
  };
  agentBaseSettingsTargets = agentBaseSettings.targets;
  nixAgentsLib = inputs.nix-agents.lib.${system};
  agentModulesFor =
    target: if target == "pi" then localAgents.piModules else localAgents.defaultModules;

  settingsDirFor =
    target: baseName: files:
    pkgs.runCommandLocal "nix-agents-${target}-${baseName}-base-settings" { } ''
      mkdir -p "$out"
      ${lib.concatMapStringsSep "\n" (
        fileName:
        let
          source = pkgs.writeText "nix-agents-${target}-${baseName}-${baseNameOf fileName}" files.${fileName};
        in
        ''
          mkdir -p "$(dirname "$out/${fileName}")"
          cp "${source}" "$out/${fileName}"
        ''
      ) (builtins.attrNames files)}
    '';

  syncBaseSettingsCommands =
    target:
    let
      baseSettings = agentBaseSettingsTargets.${target} or { };
      syncBase =
        baseName: files:
        let
          settingsDir = "$CONFIG_BASE/${target}/bases/${baseName}/settings";
          storeSettingsDir = settingsDirFor target baseName files;
          settingNames = builtins.attrNames files;
          fileCommands = lib.concatMapStringsSep "\n" (
            fileName:
            if fileName == "config.toml" then
              ''
                sync_file "${storeSettingsDir}/${fileName}" "${settingsDir}/${fileName}"
              ''
            else if fileName == "env" then
              ''
                install_lines_once "${storeSettingsDir}/${fileName}" "${settingsDir}/${fileName}"
              ''
            else
              ''
                seed_mutable_file "${storeSettingsDir}/${fileName}" "${settingsDir}/${fileName}" 0644
              ''
          ) settingNames;
        in
        ''
          echo "Bootstrapping ${target}/${baseName}/settings"
          ${fileCommands}
        '';
    in
    lib.concatStringsSep "\n" (lib.mapAttrsToList syncBase baseSettings);

  profileMetaForModules =
    target: modules:
    nixAgentsLib.mkProfileMeta {
      inherit pkgs target modules;
      inputs = agentInputs;
      src = localAgentsSrc;
    };

  profileMetaFor = target: profileMetaForModules target (agentModulesFor target);

  syncProfileCommands =
    target:
    let
      profileMeta =
        if target == "pi" then
          (profileMetaFor target) // (profileMetaForModules target localAgents.piFactoryModules)
        else
          profileMetaFor target;
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
          extraDirCommands =
            if
              target == "pi"
              && builtins.elem profileName [
                "personal-default"
                "work-default"
              ]
            then
              ''
                sync_tree "${piCommonChainsSrc}" "${profileDir}/chains"
              ''
            else
              "";
          postCommands =
            if target == "codex" then
              ''
                link_base_settings_except_config_toml "${settingsDir}" "${profileDir}"
                append_file "${profileDir}/AGENTS.md" "${codexImageGuidanceFile}"
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
          ${extraDirCommands}
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

  allBaseSettingsCommands = lib.concatStringsSep "\n" (
    map syncBaseSettingsCommands [
      "opencode"
      "claude"
      "codex"
      "pi"
    ]
  );

  piWorkAuthFile = pkgs.writeText "pi-work-auth.json" agentBaseSettings.piWorkAuth;
  piSubagentsSettingsFile = pkgs.writeText "pi-subagents-settings.json" ''
    {
      "disableDefaultAgents": true,
      "subagents": {
        "disableBuiltins": true
      }
    }
  '';
  codexImageGuidanceFile = pkgs.writeText "codex-image-guidance.md" ''
    ## Image generation

    Use Codex built-in image generation (`$imagegen` / `image_gen.imagegen`) as the default for all requested raster image generation or image editing: cats, stickers, mockups, photos, illustrations, textures, sprites, product shots, and other bitmap assets.

    Do not satisfy image-generation requests by drawing with Python/PIL, SVG, canvas, shell scripts, or placeholder code unless the user explicitly asks for code-native output.

    Use Mermaid, Graphviz, SVG, HTML/CSS/canvas, or another deterministic format when the user explicitly asks for that format, or when the requested diagram is clearly better as code-native structured output than as a generated bitmap.
  '';
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

    seed_mutable_file() {
      source_file="$1"
      target_file="$2"
      mode="$3"

      run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target_file")"

      if [ -L "$target_file" ]; then
        run ${pkgs.coreutils}/bin/rm "$target_file"
      fi

      # First seed: target does not exist (after symlink removal).
      if [ ! -e "$target_file" ]; then
        if [ -e "$target_file.backup" ]; then
          run ${pkgs.coreutils}/bin/mv "$target_file.backup" "$target_file"
        else
          run ${pkgs.coreutils}/bin/install -m "$mode" "$source_file" "$target_file"
        fi
        return
      fi

      # Target already exists as a regular file. For JSON files, shallow-merge
      # so that nix-controlled keys (e.g. "packages") are updated from source
      # while preserving runtime/user keys (e.g. "theme",
      # "lastChangelogVersion") that nix does not manage. Source values win on
      # key conflicts; target-only keys are kept. Non-JSON files (e.g. env)
      # are left untouched.
      if [ -f "$source_file" ] \
        && ${pkgs.jq}/bin/jq empty "$target_file" 2>/dev/null \
        && ${pkgs.jq}/bin/jq empty "$source_file" 2>/dev/null; then
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "DRY-RUN merge_json $source_file -> $target_file"
        else
          _seed_merge_tmp="$(${pkgs.coreutils}/bin/mktemp)"
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$target_file" "$source_file" > "$_seed_merge_tmp"
          run ${pkgs.coreutils}/bin/cp "$_seed_merge_tmp" "$target_file"
          run ${pkgs.coreutils}/bin/chmod "$mode" "$target_file"
          run ${pkgs.coreutils}/bin/rm -f "$_seed_merge_tmp"
        fi
      fi
    }

    install_lines_once() {
      source_file="$1"
      target_file="$2"

      run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target_file")"
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY-RUN install_lines_once $source_file $target_file"
        return 0
      fi

      touch "$target_file"
      chmod u+w "$target_file" 2>/dev/null || true

      while IFS= read -r line; do
        [ -n "$line" ] || continue
        if ! grep -qxF "$line" "$target_file" 2>/dev/null; then
          printf '%s\n' "$line" >> "$target_file"
        fi
      done < "$source_file"
    }

    remove_stale_base_setting_links() {
      profile_dir="$1"
      for stale in "$profile_dir"/*.backup "$profile_dir"/*.hm-symlink "$profile_dir"/.sync-agents-generated; do
        if [ -L "$stale" ]; then
          run ${pkgs.coreutils}/bin/rm "$stale"
        fi
      done
    }

    link_base_settings() {
      settings_dir="$1"
      profile_dir="$2"
      remove_stale_base_setting_links "$profile_dir"
      if [ -d "$settings_dir" ]; then
        for f in "$settings_dir"/*; do
          [ -f "$f" ] || continue
          name="''${f##*/}"
          [ "$name" = "env" ] && continue
          case "$name" in
            .*|*.backup|*.hm-symlink)
              continue
              ;;
          esac
          run ${pkgs.coreutils}/bin/ln -sfn "$f" "$profile_dir/$name" 2>/dev/null || true
        done
      fi
    }

    link_base_settings_except_config_toml() {
      settings_dir="$1"
      profile_dir="$2"
      remove_stale_base_setting_links "$profile_dir"
      if [ -d "$settings_dir" ]; then
        for f in "$settings_dir"/*; do
          [ -f "$f" ] || continue
          name="''${f##*/}"
          [ "$name" = "env" ] && continue
          [ "$name" = "config.toml" ] && continue
          case "$name" in
            .*|*.backup|*.hm-symlink)
              continue
              ;;
          esac
          run ${pkgs.coreutils}/bin/ln -sfn "$f" "$profile_dir/$name" 2>/dev/null || true
        done
      fi
    }

    append_file() {
      target_file="$1"
      source_file="$2"
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY-RUN append_file $source_file -> $target_file"
        return 0
      fi
      if [ -f "$target_file" ] && [ -f "$source_file" ]; then
        printf '\n' >> "$target_file"
        cat "$source_file" >> "$target_file"
        chmod u+w "$target_file"
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

    ${allBaseSettingsCommands}

    seed_mutable_file \
      "${piWorkAuthFile}" \
      "$CONFIG_BASE/pi/bases/work/settings/auth.json" \
      0600

    ${allSyncCommands}

    seed_mutable_file \
      "${piSubagentsSettingsFile}" \
      "$CONFIG_BASE/pi/bases/personal/profiles/personal-default/subagents.json" \
      0600

    seed_mutable_file \
      "${piSubagentsSettingsFile}" \
      "$CONFIG_BASE/pi/bases/work/profiles/work-default/subagents.json" \
      0600

    seed_mutable_file \
      "${piSubagentsSettingsFile}" \
      "$HOME/.pi/agent/subagents.json" \
      0600

    run ${pkgs.coreutils}/bin/rm -f \
      "$CONFIG_BASE/codex/bases/personal/profiles/personal-default/rules/default.rules" \
      "$CONFIG_BASE/codex/bases/work/profiles/work-default/rules/default.rules"

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
      description = "Legacy/manual sync for backend-engineering-practices skills.";
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
