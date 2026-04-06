{ nixpkgs, mylibs, inputs }:
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

  nixAgentsLib = inputs.nix-agents.lib.${system};
  nixAgentsModules = [
    (inputs.nix-agents + "/presets/default.nix")
    {
      profiles.personal = { };
      profiles.work = { };
    }
  ];

  mkNixAgentsConfig =
    target: profile:
    nixAgentsLib.mkAgentSystem {
      inherit pkgs target profile;
      modules = nixAgentsModules;
      src = inputs.nix-agents;
    };

  nixAgentsConfigs = {
    opencode = {
      personal = mkNixAgentsConfig "opencode" "personal";
      work = mkNixAgentsConfig "opencode" "work";
    };
    claude = {
      personal = mkNixAgentsConfig "claude" "personal";
      work = mkNixAgentsConfig "claude" "work";
    };
    codex = {
      personal = mkNixAgentsConfig "codex" "personal";
      work = mkNixAgentsConfig "codex" "work";
    };
    pi = {
      personal = mkNixAgentsConfig "pi" "personal";
      work = mkNixAgentsConfig "pi" "work";
    };
  };

  syncAgents = pkgs.writeShellScriptBin "sync-agents" ''
    set -euo pipefail

    sync_tree() {
      source_dir="$1"
      target_dir="$2"

      ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
      ${pkgs.coreutils}/bin/chmod -R u+w "$target_dir" 2>/dev/null || true
      ${pkgs.coreutils}/bin/rm -rf \
        "$target_dir"/* \
        "$target_dir"/.[!.]* \
        "$target_dir"/..?* \
        2>/dev/null || true
      ${pkgs.coreutils}/bin/cp -R "$source_dir"/. "$target_dir"/
    }

    sync_file() {
      source_file="$1"
      target_file="$2"

      ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target_file")"
      if [ -f "$source_file" ]; then
        ${pkgs.coreutils}/bin/cp "$source_file" "$target_file"
      else
        ${pkgs.coreutils}/bin/rm -f "$target_file"
      fi
    }

    repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || ${pkgs.coreutils}/bin/pwd)"
    source_backend_skills="${inputs.backend-engineering-practices}/skills"
    target_nix_agents_base="$HOME/.config/nix-agents"

    target_opencode_personal="$target_nix_agents_base/opencode/profiles/personal"
    target_opencode_work="$target_nix_agents_base/opencode/profiles/work"

    target_claude_personal="$target_nix_agents_base/claude/profiles/personal"
    target_claude_work="$target_nix_agents_base/claude/profiles/work"

    target_codex_personal="$target_nix_agents_base/codex/profiles/personal"
    target_codex_work="$target_nix_agents_base/codex/profiles/work"

    target_pi_personal="$target_nix_agents_base/pi/profiles/personal"
    target_pi_work="$target_nix_agents_base/pi/profiles/work"

    ${pkgs.coreutils}/bin/mkdir -p \
      "$target_opencode_personal/agents" \
      "$target_opencode_personal/skills" \
      "$target_opencode_work/agents" \
      "$target_opencode_work/skills" \
      "$target_claude_personal/agents" \
      "$target_claude_personal/skills" \
      "$target_claude_work/agents" \
      "$target_claude_work/skills" \
      "$target_codex_personal/agents" \
      "$target_codex_personal/skills" \
      "$target_codex_work/agents" \
      "$target_codex_work/skills" \
      "$target_pi_personal/agents" \
      "$target_pi_personal/skills" \
      "$target_pi_work/agents" \
      "$target_pi_work/skills"

    # OpenCode from nix-agents
    echo "Syncing OpenCode from nix-agents..."
    sync_tree "${nixAgentsConfigs.opencode.personal}/agents" "$target_opencode_personal/agents"
    sync_tree "${nixAgentsConfigs.opencode.personal}/skills" "$target_opencode_personal/skills"
    sync_file "${nixAgentsConfigs.opencode.personal}/AGENTS.md" "$target_opencode_personal/AGENTS.md"

    sync_tree "${nixAgentsConfigs.opencode.work}/agents" "$target_opencode_work/agents"
    sync_tree "${nixAgentsConfigs.opencode.work}/skills" "$target_opencode_work/skills"
    sync_file "${nixAgentsConfigs.opencode.work}/AGENTS.md" "$target_opencode_work/AGENTS.md"

    if [ -d "$source_backend_skills" ]; then
      sync_tree "$source_backend_skills" "$target_opencode_work/skills"
      echo "Synced backend-engineering-practices skills to work profile"
    fi

    # Claude from nix-agents
    echo "Syncing Claude from nix-agents..."
    sync_tree "${nixAgentsConfigs.claude.personal}/agents" "$target_claude_personal/agents"
    sync_tree "${nixAgentsConfigs.claude.personal}/skills" "$target_claude_personal/skills"
    sync_file "${nixAgentsConfigs.claude.personal}/CLAUDE.md" "$target_claude_personal/CLAUDE.md"
    sync_file "${nixAgentsConfigs.claude.personal}/settings.json" "$target_claude_personal/settings.json"
    sync_file "${nixAgentsConfigs.claude.personal}/.mcp.json" "$target_claude_personal/.mcp.json"

    sync_tree "${nixAgentsConfigs.claude.work}/agents" "$target_claude_work/agents"
    sync_tree "${nixAgentsConfigs.claude.work}/skills" "$target_claude_work/skills"
    sync_file "${nixAgentsConfigs.claude.work}/CLAUDE.md" "$target_claude_work/CLAUDE.md"
    sync_file "${nixAgentsConfigs.claude.work}/settings.json" "$target_claude_work/settings.json"
    sync_file "${nixAgentsConfigs.claude.work}/.mcp.json" "$target_claude_work/.mcp.json"

    # Codex from nix-agents
    echo "Syncing Codex from nix-agents..."
    sync_tree "${nixAgentsConfigs.codex.personal}/agents" "$target_codex_personal/agents"
    sync_tree "${nixAgentsConfigs.codex.personal}/skills" "$target_codex_personal/skills"
    sync_file "${nixAgentsConfigs.codex.personal}/AGENTS.md" "$target_codex_personal/AGENTS.md"
    sync_file "${nixAgentsConfigs.codex.personal}/mcp.json" "$target_codex_personal/mcp.json"

    sync_tree "${nixAgentsConfigs.codex.work}/agents" "$target_codex_work/agents"
    sync_tree "${nixAgentsConfigs.codex.work}/skills" "$target_codex_work/skills"
    sync_file "${nixAgentsConfigs.codex.work}/AGENTS.md" "$target_codex_work/AGENTS.md"
    sync_file "${nixAgentsConfigs.codex.work}/mcp.json" "$target_codex_work/mcp.json"

    # Pi from nix-agents
    echo "Syncing Pi from nix-agents..."
    sync_tree "${nixAgentsConfigs.pi.personal}/agents" "$target_pi_personal/agents"
    sync_tree "${nixAgentsConfigs.pi.personal}/skills" "$target_pi_personal/skills"
    sync_file "${nixAgentsConfigs.pi.personal}/AGENTS.md" "$target_pi_personal/AGENTS.md"
    if [ -d "${nixAgentsConfigs.pi.personal}/extensions" ]; then
      sync_tree "${nixAgentsConfigs.pi.personal}/extensions" "$target_pi_personal/extensions"
    fi
    if [ -d "${nixAgentsConfigs.pi.personal}/prompts" ]; then
      sync_tree "${nixAgentsConfigs.pi.personal}/prompts" "$target_pi_personal/prompts"
    fi

    sync_tree "${nixAgentsConfigs.pi.work}/agents" "$target_pi_work/agents"
    sync_tree "${nixAgentsConfigs.pi.work}/skills" "$target_pi_work/skills"
    sync_file "${nixAgentsConfigs.pi.work}/AGENTS.md" "$target_pi_work/AGENTS.md"
    if [ -d "${nixAgentsConfigs.pi.work}/extensions" ]; then
      sync_tree "${nixAgentsConfigs.pi.work}/extensions" "$target_pi_work/extensions"
    fi
    if [ -d "${nixAgentsConfigs.pi.work}/prompts" ]; then
      sync_tree "${nixAgentsConfigs.pi.work}/prompts" "$target_pi_work/prompts"
    fi

    echo ""
    echo "Synced:"
    echo "  OpenCode -> $target_opencode_personal and $target_opencode_work"
    echo "  Claude   -> $target_claude_personal and $target_claude_work"
    echo "  Codex    -> $target_codex_personal and $target_codex_work"
    echo "  Pi       -> $target_pi_personal and $target_pi_work"
  '';
in
(
  builtins.listToAttrs (
    map (name: {
      inherit name;
      value = mylibs.app.mkApp name system;
    }) appCommands
  )
)
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
      description = "Sync agent configs from nix-agents to local config directories.";
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
