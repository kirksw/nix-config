{
  self,
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  claudeBin = "${pkgs.llm-agents.claude-code}/bin/claude";

  mkClaudeWrapper = pkgs.writeShellScriptBin "claude" ''
    set -euo pipefail

    ANTHROPIC_KEY_PATH="${config.sops.secrets."api/lunar/anthropic".path}"
    OPENAI_KEY_PATH="${config.sops.secrets."api/lunar/openai".path}"
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
      export AWS_BEARER_TOKEN_BEDROCK="$(cat "$ANTHROPIC_KEY_PATH")"
      export CLAUDE_CODE_USE_BEDROCK=1
      export AWS_REGION=eu-west-1
      export ANTHROPIC_MODEL='eu.anthropic.claude-sonnet-4-6'
      export ANTHROPIC_DEFAULT_OPUS_MODEL='eu.anthropic.claude-opus-4-6-v1'
      export ANTHROPIC_SMALL_FAST_MODEL='eu.anthropic.claude-haiku-4-5-20251001-v1:0'

      # Codex plugin (codex-plugin-cc) inherits env from Claude Code;
      # export OpenAI credentials so the app-server/broker can use them.
      if [[ -f "$OPENAI_KEY_PATH" ]]; then
        export OPENAI_API_KEY="$(cat "$OPENAI_KEY_PATH")"
        export OPENAI_BASE_URL="https://eu.api.openai.com/v1"
      fi

      echo "claude: using work profile (lunar, API key)" >&2
      exec "$CLAUDE_BIN" "$@"
    else
      unset ANTHROPIC_API_KEY 2>/dev/null || true
      echo "claude: using personal profile (subscription)" >&2
      exec "$CLAUDE_BIN" "$@"
    fi
  '';
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
      "api/lunar/openai" = {
        sopsFile = "${self}/secrets/api/lunar.yaml";
        key = "openai";
        mode = "0400";
      };
    };

    home.packages = [
      mkClaudeWrapper
    ];
  };
}
