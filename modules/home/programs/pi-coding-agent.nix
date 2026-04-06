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
  nixAgentsPiProfilesDir = "${homeDir}/.config/nix-agents/pi/profiles";
  legacyNixAgentsPiProfilesDir = "${homeDir}/.local/share/nix-agents/pi/profiles";
  livePiAgentDir = "${homeDir}/.pi/agent";

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

    resolve_pi_assets_dir() {
      local profile_name="$1"
      local preferred_dir="${nixAgentsPiProfilesDir}/$profile_name"
      local legacy_dir="${legacyNixAgentsPiProfilesDir}/$profile_name"

      if [[ -d "$preferred_dir" ]]; then
        printf '%s\n' "$preferred_dir"
      elif [[ -d "$legacy_dir" ]]; then
        printf '%s\n' "$legacy_dir"
      else
        echo "error: missing Pi agent assets at $preferred_dir" >&2
        echo "checked legacy path $legacy_dir as well" >&2
        echo "run 'nix run .#sync-agents' to populate profile-specific nix-agents assets" >&2
        exit 1
      fi
    }

    sync_pi_assets() {
      local profile_name="$1"
      local source_dir

      source_dir="$(resolve_pi_assets_dir "$profile_name")"

      mkdir -p "${livePiAgentDir}"
      ln -sfn "$source_dir/agents" "${livePiAgentDir}/agents"
      ln -sfn "$source_dir/skills" "${livePiAgentDir}/skills"
      if [[ -f "$source_dir/AGENTS.md" ]]; then
        ln -sfn "$source_dir/AGENTS.md" "${livePiAgentDir}/AGENTS.md"
      else
        rm -f "${livePiAgentDir}/AGENTS.md"
      fi
      if [[ -d "$source_dir/extensions" ]]; then
        ln -sfn "$source_dir/extensions" "${livePiAgentDir}/extensions"
      else
        rm -f "${livePiAgentDir}/extensions"
      fi
      if [[ -d "$source_dir/prompts" ]]; then
        ln -sfn "$source_dir/prompts" "${livePiAgentDir}/prompts"
      else
        rm -f "${livePiAgentDir}/prompts"
      fi
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
      sync_pi_assets work
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
      sync_pi_assets personal
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
