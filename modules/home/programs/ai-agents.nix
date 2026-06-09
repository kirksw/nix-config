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
  mkWrappedToolArgs =
    args:
    if (builtins.functionArgs nixAgentsLib.mkWrappedTool) ? syncMode then
      args // { syncMode = "bootstrap"; }
    else
      args;
  localAgents = import ../../../agents { inherit pkgs; };
  localAgentsSrc = ../../../agents;
  agentInputs = inputs // {
    inherit self;
  };

  # Modules shared across all target builds
  nixAgentsModules = localAgents.defaultModules;
  piAgentsModules = localAgents.piModules;

  piWorkSettings = builtins.toJSON {
    defaultProvider = "openai";
    defaultModel = "gpt-5.4";
    defaultThinkingLevel = "medium";
    enabledModels = [
      "gpt-5.5"
      "gpt-5.4"
      "gpt-5.4-mini"
      "gpt-5.3-codex-spark"
      "claude-opus-4-8"
      "claude-sonnet-4-6"
    ];
    packages = [ "npm:pi-mcp-adapter@2.8.0" ];
  };

  piWorkModels = builtins.toJSON {
    providers.openai.baseUrl = "https://eu.api.openai.com/v1";
  };

  piWorkMcp = builtins.toJSON {
    mcpServers = {
      granola = {
        url = "https://mcp.granola.ai/mcp";
        auth = "oauth";
        lifecycle = "lazy";
      };
      slack = {
        command = "npx";
        args = [
          "-y"
          "@jtalk22/slack-mcp"
        ];
        lifecycle = "lazy";
      };
    };
  };

  piWorkAuth = builtins.toJSON {
    openai = {
      type = "api_key";
      key = "OPENAI_API_KEY";
    };
    anthropic = {
      type = "api_key";
      key = "ANTHROPIC_API_KEY";
    };
  };

  codexPersonalSettings = ''
    approvals_reviewer = "guardian_subagent"
  '';

  codexPersonalRules = ''
    prefix_rule(pattern=["git", "add"], decision="allow")
    prefix_rule(pattern=["git", "clone"], decision="allow")
    prefix_rule(pattern=["git", "fetch"], decision="allow")
    prefix_rule(pattern=["git", "ls-remote"], decision="allow")
    prefix_rule(pattern=["git", "pull"], decision="allow")
    prefix_rule(pattern=["gh", "pr", "merge"], decision="allow")
    prefix_rule(pattern=["nix", "build"], decision="allow")
    prefix_rule(pattern=["nix", "eval", "--impure", "--expr"], decision="allow")
  '';
  codexPersonalRulesFile = pkgs.writeText "codex-personal-default.rules" codexPersonalRules;

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

  codexWorkRules = ''
    prefix_rule(pattern=["docker", "version"], decision="allow")
    prefix_rule(pattern=["git", "clone"], decision="allow")
    prefix_rule(pattern=["git", "fetch"], decision="allow")
    prefix_rule(pattern=["git", "ls-remote"], decision="allow")
    prefix_rule(pattern=["git", "pull"], decision="allow")
    prefix_rule(pattern=["git", "push", "origin"], decision="allow")
    prefix_rule(pattern=["nix", "develop", "--command", "mill"], decision="allow")
  '';
  codexWorkRulesFile = pkgs.writeText "codex-work-default.rules" codexWorkRules;

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
  opencodePkg = nixAgentsLib.mkWrappedTool (mkWrappedToolArgs {
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
  });

  claudePkg = nixAgentsLib.mkWrappedTool (mkWrappedToolArgs {
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
  });

  codexPkg = nixAgentsLib.mkWrappedTool (mkWrappedToolArgs {
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
  });

  piPkg = nixAgentsLib.mkWrappedTool (mkWrappedToolArgs {
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
  });
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
          _pi_session_profile=""
          _d="$PWD"
          while [ "$_d" != "/" ] && [ -n "$_d" ]; do
            if [ -f "$_d/.nix-agents-profile" ]; then
              _pi_session_profile="$(cat "$_d/.nix-agents-profile")"
              break
            fi
            _d="''${_d%/*}"
          done
          if [ -z "$_pi_session_profile" ]; then
            if is_lunar_project; then
              _pi_session_profile="work-default"
            else
              _pi_session_profile="personal-default"
            fi
          fi
          case "$_pi_session_profile" in
            personal-default|work-default) ;;
            *) _pi_session_profile="personal-default" ;;
          esac
          export PI_CODING_AGENT_SESSION_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/pi/sessions/$_pi_session_profile"
          mkdir -p "$PI_CODING_AGENT_SESSION_DIR"

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
        "nix-agents/pi/bases/work/settings/mcp.json".text = piWorkMcp;
        "nix-agents/pi/bases/work/settings/models.json".text = piWorkModels;
        "nix-agents/pi/bases/work/settings/settings.json".text = piWorkSettings;
        "nix-agents/pi/bases/work/settings/env".text = ''
          if [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
            export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
          fi
          if [ -n "''${LUNAR_ANTHROPIC_API_KEY:-}" ]; then
            export ANTHROPIC_API_KEY="$LUNAR_ANTHROPIC_API_KEY"
          fi
        '';
      })
    ];

    home.activation.codexGitReadApprovalRules = lib.mkIf config.homeModules.codex.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        install_codex_rules() {
          local source_file="$1"
          local target_file="$2"

          mkdir -p "$(dirname "$target_file")"
          touch "$target_file"
          chmod u+w "$target_file" 2>/dev/null || true

          while IFS= read -r rule; do
            [ -n "$rule" ] || continue
            if ! grep -qxF "$rule" "$target_file" 2>/dev/null; then
              printf '%s\n' "$rule" >> "$target_file"
            fi
          done < "$source_file"
        }

        install_codex_rules \
          "${codexPersonalRulesFile}" \
          "$HOME/.config/nix-agents/codex/bases/personal/profiles/personal-default/rules/default.rules"

        install_codex_rules \
          "${codexWorkRulesFile}" \
          "$HOME/.config/nix-agents/codex/bases/work/profiles/work-default/rules/default.rules"
      ''
    );
  };
}
