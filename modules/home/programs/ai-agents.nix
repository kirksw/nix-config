{
  self,
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  nixAgentsLib = inputs.nix-agents.lib.${system};
  localAgents = import ../../../agents { inherit pkgs; };
  localAgentsSrc = ../../../agents;
  agentInputs = inputs // {
    inherit self;
  };

  # Modules shared across all target builds
  nixAgentsModules = localAgents.defaultModules;
  piAgentsModules = nixAgentsModules ++ [
    (
      { lib, ... }:
      {
        profiles.work-default.tierMapping = {
          fast = lib.mkForce "openai/gpt-5.4";
          balanced = lib.mkForce "openai/gpt-5.4";
          powerful = lib.mkForce "openai/gpt-5.4";
          reasoning = lib.mkForce "openai/gpt-5.4";
        };
      }
    )
  ];

  piWorkSettings = builtins.toJSON {
    defaultProvider = "openai";
    defaultModel = "gpt-5.4";
    defaultThinkingLevel = "medium";
    enabledModels = [ "gpt-5.4" ];
  };

  piWorkModels = builtins.toJSON {
    providers.openai.baseUrl = "https://eu.api.openai.com/v1";
  };

  piWorkAuth = builtins.toJSON {
    openai = {
      type = "api_key";
      key = "OPENAI_API_KEY";
    };
  };

  codexPersonalSettings = ''
    approvals_reviewer = "guardian_subagent"
  '';

  codexWorkSettings = ''
    model = "gpt-5.5"
    model_reasoning_effort = "high"
    openai_base_url = "https://eu.api.openai.com/v1"
    plan_mode_reasoning_effort = "high"
    approvals_reviewer = "guardian_subagent"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-continuum"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-dbt"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/lunar-way-hubble-transformations"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/data-agents"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-flink-platform"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-rbac-controller"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-sandbox-finance"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/aws-lunar-data-prod-resources"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-wiki"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-starrocks"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-async-schema-ingestion"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/capi-workload-clusters"]
    trust_level = "trusted"

    [notice.model_migrations]
    "gpt-5.3-codex" = "gpt-5.4"

    [tui]
    theme = "catppuccin-latte"

    [tui.model_availability_nux]
    "gpt-5.5" = 4

    [mcp_servers.linear]
    url = "https://mcp.linear.app/mcp"

    [mcp_servers.sourcegraph]
    url = "https://lunar.sourcegraph.com/.api/mcp"
  '';

  # Thin wrapper that reads sops-decrypted secrets into env vars,
  # then execs the nix-agents wrapper which handles profile detection
  # and credential resolution.
  mkCredWrapper =
    target: nixAgentsPkg: extraPreExec:
    pkgs.writeShellScriptBin target ''
      set -euo pipefail

      is_lunar_project() {
        case "$(pwd)" in
          "$HOME"/git/github.com/lunarway|"$HOME"/git/github.com/lunarway/*|"$HOME"/projects/lunar|"$HOME"/projects/lunar/*)
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }

      # Export sops-decrypted credentials as env vars.
      # The nix-agents wrapper picks these up via providers with credentialSource = "env".
      ZAI_SECRET_PATH="${config.sops.secrets."zai".path}"
      MINIMAX_SECRET_PATH="${config.sops.secrets."minimax".path}"
      LUNAR_OPENAI_KEY_PATH="${config.sops.secrets."api/lunar/openai".path}"
      LUNAR_ANTHROPIC_KEY_PATH="${config.sops.secrets."api/lunar/anthropic".path}"
      GIT_PAT_PATH="${config.sops.secrets."git/pat".path}"

      if [ -f "$ZAI_SECRET_PATH" ]; then
        export PERSONAL_ZAI_API_KEY="$(cat "$ZAI_SECRET_PATH")"
      fi
      if [ -f "$MINIMAX_SECRET_PATH" ]; then
        export PERSONAL_MINIMAX_API_KEY="$(cat "$MINIMAX_SECRET_PATH")"
      fi
      if [ -f "$LUNAR_OPENAI_KEY_PATH" ]; then
        export LUNAR_OPENAI_API_KEY="$(cat "$LUNAR_OPENAI_KEY_PATH")"
      fi
      if [ -f "$LUNAR_ANTHROPIC_KEY_PATH" ]; then
        export LUNAR_ANTHROPIC_API_KEY="$(cat "$LUNAR_ANTHROPIC_KEY_PATH")"
      fi
      if [ -f "$GIT_PAT_PATH" ]; then
        export CODEX_GITHUB_PERSONAL_ACCESS_TOKEN="$(tr -d '[:space:]' < "$GIT_PAT_PATH")"
      fi

      ${extraPreExec}

      exec "${nixAgentsPkg}/bin/${target}" "$@"
    '';

  # Build the nix-agents wrapped tool for each target
  opencodePkg = nixAgentsLib.mkWrappedTool {
    inherit pkgs;
    target = "opencode";
    tool = pkgs.llm-agents.opencode;
    agentSystem = nixAgentsLib.mkAgentSystem {
      inherit pkgs;
      target = "opencode";
      inputs = agentInputs;
      modules = nixAgentsModules;
      src = localAgentsSrc;
    };
    profileMeta = nixAgentsLib.mkProfileMeta {
      inherit pkgs;
      target = "opencode";
      inputs = agentInputs;
      modules = nixAgentsModules;
      src = localAgentsSrc;
    };
  };

  claudePkg = nixAgentsLib.mkWrappedTool {
    inherit pkgs;
    target = "claude";
    tool = pkgs.llm-agents.claude-code;
    agentSystem = nixAgentsLib.mkAgentSystem {
      inherit pkgs;
      target = "claude";
      inputs = agentInputs;
      modules = nixAgentsModules;
    };
    profileMeta = nixAgentsLib.mkProfileMeta {
      inherit pkgs;
      target = "claude";
      inputs = agentInputs;
      modules = nixAgentsModules;
    };
  };

  codexPkg = nixAgentsLib.mkWrappedTool {
    inherit pkgs;
    target = "codex";
    tool = pkgs.llm-agents.codex;
    agentSystem = nixAgentsLib.mkAgentSystem {
      inherit pkgs;
      target = "codex";
      inputs = agentInputs;
      modules = nixAgentsModules;
    };
    profileMeta = nixAgentsLib.mkProfileMeta {
      inherit pkgs;
      target = "codex";
      inputs = agentInputs;
      modules = nixAgentsModules;
    };
  };

  piPkg = nixAgentsLib.mkWrappedTool {
    inherit pkgs;
    target = "pi";
    tool = pkgs.llm-agents.pi;
    agentSystem = nixAgentsLib.mkAgentSystem {
      inherit pkgs;
      target = "pi";
      inputs = agentInputs;
      modules = piAgentsModules;
      src = localAgentsSrc;
    };
    profileMeta = nixAgentsLib.mkProfileMeta {
      inherit pkgs;
      target = "pi";
      inputs = agentInputs;
      modules = piAgentsModules;
      src = localAgentsSrc;
    };
  };
in
{
  options = {
    homeModules.claudeCode.enable = lib.mkEnableOption "enables claude code";
    homeModules.opencode.enable = lib.mkEnableOption "enables opencode";
    homeModules.codex.enable = lib.mkEnableOption "enables codex";
    homeModules.piCodingAgent.enable = lib.mkEnableOption "enables pi-coding-agent";
    homeModules.openshell.enable = lib.mkEnableOption "enables openshell";
    homeModules.multica.enable = lib.mkEnableOption "enables multica";
  };

  config = {
    # --- sops secrets (shared across all ai tools) ---
    sops.secrets = lib.mkMerge [
      (lib.mkIf (config.homeModules.opencode.enable || config.homeModules.piCodingAgent.enable) {
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
      })
      (lib.mkIf
        (
          config.homeModules.claudeCode.enable
          || config.homeModules.opencode.enable
          || config.homeModules.piCodingAgent.enable
          || config.homeModules.codex.enable
        )
        {
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
        }
      )
      (lib.mkIf config.homeModules.codex.enable {
        "git/pat" = {
          sopsFile = "${self}/secrets/git/pat.yaml";
          key = "pat";
          mode = "0400";
        };
      })
    ];

    # --- install packages ---
    home.packages = lib.mkMerge [
      (lib.mkIf config.homeModules.opencode.enable [
        (mkCredWrapper "opencode" opencodePkg ''
          if is_lunar_project; then
            if [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
              export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
            fi
            if [ -n "''${LUNAR_ANTHROPIC_API_KEY:-}" ]; then
              export ANTHROPIC_API_KEY="$LUNAR_ANTHROPIC_API_KEY"
            fi
          else
            if [ -n "''${PERSONAL_ZAI_API_KEY:-}" ]; then
              export zai_token="$PERSONAL_ZAI_API_KEY"
            fi
            if [ -n "''${PERSONAL_MINIMAX_API_KEY:-}" ]; then
              export MINIMAX_API_KEY="$PERSONAL_MINIMAX_API_KEY"
            fi
          fi
        '')
      ])
      (lib.mkIf config.homeModules.claudeCode.enable [
        (mkCredWrapper "claude" claudePkg "")
      ])
      (lib.mkIf config.homeModules.codex.enable [
        (mkCredWrapper "codex" codexPkg ''
          if is_lunar_project && [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
            export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
          fi
        '')
      ])
      (lib.mkIf config.homeModules.piCodingAgent.enable [
        (mkCredWrapper "pi" piPkg ''
          if is_lunar_project; then
            if [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
              export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
            fi
            if [ -n "''${LUNAR_ANTHROPIC_API_KEY:-}" ]; then
              export ANTHROPIC_API_KEY="$LUNAR_ANTHROPIC_API_KEY"
            fi
          else
            if [ -n "''${PERSONAL_ZAI_API_KEY:-}" ]; then
              export ZAI_API_KEY="$PERSONAL_ZAI_API_KEY"
            fi
            if [ -n "''${PERSONAL_MINIMAX_API_KEY:-}" ]; then
              export MINIMAX_API_KEY="$PERSONAL_MINIMAX_API_KEY"
            fi
          fi
        '')
      ])
      (lib.mkIf config.homeModules.multica.enable [
        self.packages.${system}.multica
      ])
      (lib.mkIf config.homeModules.openshell.enable [
        inputs.nix-agents.packages.${system}.openshell
      ])
    ];

    xdg.configFile = lib.mkMerge [
      (lib.mkIf config.homeModules.codex.enable {
        "nix-agents/codex/bases/personal/settings/config.toml".text = codexPersonalSettings;
        "nix-agents/codex/bases/work/settings/config.toml".text = codexWorkSettings;
      })
      (lib.mkIf config.homeModules.piCodingAgent.enable {
        "nix-agents/pi/bases/work/settings/auth.json".text = piWorkAuth;
        "nix-agents/pi/bases/work/settings/models.json".text = piWorkModels;
        "nix-agents/pi/bases/work/settings/settings.json".text = piWorkSettings;
        "nix-agents/pi/bases/work/settings/env".text = ''
          if [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
            export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
          fi
        '';
      })
    ];
  };
}
