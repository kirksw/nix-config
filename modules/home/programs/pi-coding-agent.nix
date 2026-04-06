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

  profileBase = "${homeDir}/.config/pi/profiles";
  dataProfileBase = "${homeDir}/.local/share/pi/profiles";

  mkPiWrapper = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail

    ZAI_SECRET_PATH="${config.sops.secrets."zai".path}"
    MINIMAX_SECRET_PATH="${config.sops.secrets."minimax".path}"
    LUNAR_OPENAI_KEY_PATH="${config.sops.secrets."api/lunar/openai".path}"
    LUNAR_ANTHROPIC_KEY_PATH="${config.sops.secrets."api/lunar/anthropic".path}"
    PI_BIN="${pkgs.llm-agents.pi}/bin/pi"

    is_work_project() {
      [[ "$(pwd)" == ~/git/github.com/lunarway?(/*) ]]
    }

    if is_work_project; then
      if [[ ! -f "$LUNAR_OPENAI_KEY_PATH" ]]; then
        echo "error: missing work API key at $LUNAR_OPENAI_KEY_PATH" >&2
        exit 1
      fi
      if [[ ! -f "$LUNAR_ANTHROPIC_KEY_PATH" ]]; then
        echo "error: missing Claude API key at $LUNAR_ANTHROPIC_KEY_PATH" >&2
        echo "add 'anthropic' key to secrets/api/lunar.yaml with sops" >&2
        exit 1
      fi
      export XDG_CONFIG_HOME="${profileBase}/work"
      export XDG_DATA_HOME="${dataProfileBase}/work"
      export OPENAI_API_KEY="$(cat "$LUNAR_OPENAI_KEY_PATH")"
      export OPENAI_BASE_URL="https://eu.api.openai.com/v1"
      export ANTHROPIC_API_KEY="$(cat "$LUNAR_ANTHROPIC_KEY_PATH")"
      echo "pi: using work profile (lunar)" >&2
      exec "$PI_BIN" "$@"
    else
      if [[ ! -f "$ZAI_SECRET_PATH" ]]; then
        echo "error: secret not found at $ZAI_SECRET_PATH" >&2
        echo "make sure sops is enabled and secrets are activated" >&2
        exit 1
      fi
      export XDG_CONFIG_HOME="${profileBase}/personal"
      export XDG_DATA_HOME="${dataProfileBase}/personal"
      export ZAI_API_KEY="$(cat "$ZAI_SECRET_PATH")"
      export MINIMAX_API_KEY="$(cat "$MINIMAX_SECRET_PATH")"
      echo "pi: using personal profile" >&2
      exec "$PI_BIN" "$@"
    fi
  '';
in
{
  options = {
    homeModules.piCodingAgent.enable = lib.mkEnableOption "enables pi-coding-agent";
  };

  config = lib.mkIf config.homeModules.piCodingAgent.enable {
    sops.secrets = {
      "zai" = {
        sopsFile = "${self}/secrets/api/default.yaml";
        key = "zai";
        mode = "0400";
      };
      "minimax" = {
        sopsFile = "${self}/secrets/api/default.yaml";
        key = "minimax";
        mode = "0400";
      };
      "api/lunar/openai" = {
        sopsFile = "${self}/secrets/api/lunar.yaml";
        key = "openai";
        mode = "0400";
      };
      "api/lunar/anthropic" = {
        sopsFile = "${self}/secrets/api/lunar.yaml";
        key = "anthropic";
        mode = "0400";
      };
    };

    home.packages = [
      mkPiWrapper
    ];
  };
}
