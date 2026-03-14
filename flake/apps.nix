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

  nixAgentsPkgs = inputs.nix-agents.packages.${system};
  opencodeConfig = nixAgentsPkgs.opencode-config;
  claudeConfig = nixAgentsPkgs.claude-config;
  codexConfig = nixAgentsPkgs.codex-config;
  piConfig = nixAgentsPkgs.pi-config;

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

    repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || ${pkgs.coreutils}/bin/pwd)"
    source_backend_skills="${inputs.backend-engineering-practices}/skills"

    target_opencode_personal="$HOME/.config/opencode/profiles/personal/opencode"
    target_opencode_work="$HOME/.config/opencode/profiles/work/opencode"

    target_claude_root="$HOME/.local/share/nix-agents/claude"

    target_codex_personal="$HOME/.local/share/nix-agents/codex/personal"
    target_codex_work="$HOME/.local/share/nix-agents/codex/work"

    target_pi_root="$HOME/.pi/agent"
    target_pi_agents="$target_pi_root/agents"
    target_pi_skills="$target_pi_root/skills"
    target_pi_extensions="$target_pi_root/extensions"
    target_pi_prompts="$target_pi_root/prompts"
    target_pi_agents_guide="$target_pi_root/AGENTS.md"

    ${pkgs.coreutils}/bin/mkdir -p \
      "$target_opencode_personal/agents" \
      "$target_opencode_personal/skills" \
      "$target_opencode_work/agents" \
      "$target_opencode_work/skills" \
      "$target_claude_root/agents" \
      "$target_claude_root/skills" \
      "$target_codex_personal/agents" \
      "$target_codex_personal/skills" \
      "$target_codex_work/agents" \
      "$target_codex_work/skills" \
      "$target_pi_agents" \
      "$target_pi_skills" \
      "$target_pi_extensions" \
      "$target_pi_prompts"

    # OpenCode from nix-agents
    echo "Syncing OpenCode from nix-agents..."
    sync_tree "${opencodeConfig}/agents" "$target_opencode_personal/agents"
    sync_tree "${opencodeConfig}/skills" "$target_opencode_personal/skills"
    ${pkgs.coreutils}/bin/cp "${opencodeConfig}/AGENTS.md" "$target_opencode_personal/AGENTS.md" 2>/dev/null || true
    ${pkgs.coreutils}/bin/cp "${opencodeConfig}/opencode.json" "$target_opencode_personal/opencode.json" 2>/dev/null || true

    sync_tree "${opencodeConfig}/agents" "$target_opencode_work/agents"
    sync_tree "${opencodeConfig}/skills" "$target_opencode_work/skills"
    ${pkgs.coreutils}/bin/cp "${opencodeConfig}/AGENTS.md" "$target_opencode_work/AGENTS.md" 2>/dev/null || true
    ${pkgs.coreutils}/bin/cp "${opencodeConfig}/opencode.json" "$target_opencode_work/opencode.json" 2>/dev/null || true

    if [ -d "$source_backend_skills" ]; then
      sync_tree "$source_backend_skills" "$target_opencode_work/skills"
      echo "Synced backend-engineering-practices skills to work profile"
    fi

    # Claude from nix-agents
    echo "Syncing Claude from nix-agents..."
    sync_tree "${claudeConfig}/agents" "$target_claude_root/agents"
    sync_tree "${claudeConfig}/skills" "$target_claude_root/skills"
    ${pkgs.coreutils}/bin/cp "${claudeConfig}/CLAUDE.md" "$target_claude_root/CLAUDE.md" 2>/dev/null || true
    ${pkgs.coreutils}/bin/cp "${claudeConfig}/settings.json" "$target_claude_root/settings.json" 2>/dev/null || true
    ${pkgs.coreutils}/bin/cp "${claudeConfig}/.mcp.json" "$target_claude_root/.mcp.json" 2>/dev/null || true

    # Codex from nix-agents
    echo "Syncing Codex from nix-agents..."
    sync_tree "${codexConfig}/agents" "$target_codex_personal/agents"
    sync_tree "${codexConfig}/skills" "$target_codex_personal/skills"
    ${pkgs.coreutils}/bin/cp "${codexConfig}/AGENTS.md" "$target_codex_personal/AGENTS.md" 2>/dev/null || true

    sync_tree "${codexConfig}/agents" "$target_codex_work/agents"
    sync_tree "${codexConfig}/skills" "$target_codex_work/skills"
    ${pkgs.coreutils}/bin/cp "${codexConfig}/AGENTS.md" "$target_codex_work/AGENTS.md" 2>/dev/null || true

    # Pi from nix-agents
    if [ -d "${piConfig}" ]; then
      echo "Syncing Pi from nix-agents..."
      sync_tree "${piConfig}/agents" "$target_pi_agents"
      sync_tree "${piConfig}/skills" "$target_pi_skills"
      ${pkgs.coreutils}/bin/cp "${piConfig}/AGENTS.md" "$target_pi_agents_guide" 2>/dev/null || true
      if [ -d "${piConfig}/extensions" ]; then
        sync_tree "${piConfig}/extensions" "$target_pi_extensions"
      fi
      if [ -d "${piConfig}/prompts" ]; then
        sync_tree "${piConfig}/prompts" "$target_pi_prompts"
      fi
    fi

    echo ""
    echo "Synced:"
    echo "  OpenCode -> $target_opencode_personal and $target_opencode_work"
    echo "  Claude   -> $target_claude_root"
    echo "  Codex    -> $target_codex_personal and $target_codex_work"
    [ -d "${piConfig}" ] && echo "  Pi       -> $target_pi_root"
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
