{
  self,
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  swePrunerCommand = config.homeModules.swePrunerMcp.command;

  claudeBin = "${pkgs.llm-agents.claude-code}/bin/claude";

  mkClaudeWrapper = pkgs.writeShellScriptBin "claude" ''
    set -euo pipefail

    ANTHROPIC_KEY_PATH="${config.sops.secrets."api/lunar/anthropic".path}"
    CLAUDE_BIN="${claudeBin}"

    is_work_project() {
      [[ "$(pwd)" == ~/git/github.com/lunarway?(/*) ]]
    }

    if is_work_project; then
      if [[ ! -f "$ANTHROPIC_KEY_PATH" ]]; then
        echo "error: missing Anthropic API key at $ANTHROPIC_KEY_PATH" >&2
        echo "add 'anthropic' key to secrets/api/lunar.yaml with sops" >&2
        exit 1
      fi
      export ANTHROPIC_API_KEY="$(cat "$ANTHROPIC_KEY_PATH")"
      echo "claude: using work profile (lunar, API key)" >&2
      exec "$CLAUDE_BIN" "$@"
    else
      unset ANTHROPIC_API_KEY 2>/dev/null || true
      echo "claude: using personal profile (subscription)" >&2
      exec "$CLAUDE_BIN" "$@"
    fi
  '';

  # MCP config for swe-pruner (written to ~/.claude.json mcpServers section)
  swePrunerMcpConfig = lib.optionalAttrs
    (config.homeModules.swePrunerMcp.enable && swePrunerCommand != null)
    {
      swe-pruner = {
        command = swePrunerCommand;
        env = {
          MODEL_PATH = "${homeDir}/.cache/swe-pruner/models/code-pruner";
          STATS_FILE = "${homeDir}/.cache/swe-pruner/stats.json";
        };
      };
    };
in
{
  options = {
    homeModules.claudeCode.enable = lib.mkEnableOption "enables claude code";
  };

  config = lib.mkIf config.homeModules.claudeCode.enable {
    sops.secrets = {
      "api/lunar/anthropic" = {
        sopsFile = "${self}/secrets/api/lunar.yaml";
        key = "anthropic";
        mode = "0400";
      };
    };

    home.packages = [
      mkClaudeWrapper
    ];
  };
}
