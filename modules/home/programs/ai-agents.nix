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
  workOpenAIBaseUrl = "https://eu.api.openai.com/v1";
  omnigentVendorPath = lib.makeBinPath [
    pkgs.llm-agents.claude-code
    pkgs.llm-agents.codex
    pkgs.llm-agents.pi
  ];
  agentInputs = inputs // {
    inherit self;
  };

  # Modules shared across all target builds
  nixAgentsModules = localAgents.defaultModules;
  piAgentsModules = localAgents.piModules;

  # Thin wrapper that reads sops-decrypted secrets into env vars,
  # then execs the nix-agents wrapper which handles profile detection
  # and credential resolution.
  mkCredWrapper =
    target: nixAgentsPkg: extraPreExec:
    pkgs.writeShellScriptBin target ''
      set -euo pipefail

      is_lunar_project() {
        case "$(pwd)" in
          "$HOME"/git/github.com/lunarway|"$HOME"/git/github.com/lunarway/*|"$HOME"/git/github.com/kirksw/lunar-notes|"$HOME"/git/github.com/kirksw/lunar-notes/*|"$HOME"/git/github.com/kirksw/lunarOS|"$HOME"/git/github.com/kirksw/lunarOS/*|"$HOME"/projects/lunar|"$HOME"/projects/lunar/*)
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

  mkOmnigentServerScript =
    profile: port: envBlock:
    pkgs.writeShellScript "omnigent-${profile}-server" ''
      set -euo pipefail

      export PATH="${omnigentVendorPath}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:$PATH"
      export OMNIGENT_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}/omnigent/profiles/${profile}"
      export OMNIGENT_DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/omnigent/profiles/${profile}"
      mkdir -p "$OMNIGENT_CONFIG_HOME" "$OMNIGENT_DATA_DIR/artifacts" "$OMNIGENT_DATA_DIR/logs"

      # Keep Omnigent's native Codex sessions away from the user's shared
      # ~/.codex/config.toml. Omnigent copies config.toml into a per-session
      # CODEX_HOME, and the current shared config makes hooks/list load zero
      # hooks, which disables policy enforcement. We only bridge auth.json.
      export CODEX_HOME="$OMNIGENT_CONFIG_HOME/codex-home"
      export CLAUDE_CONFIG_DIR="$OMNIGENT_CONFIG_HOME/claude-code"
      export OMNIGENT_CLAUDE_BIN="${pkgs.llm-agents.claude-code}/bin/claude"
      mkdir -p "$CODEX_HOME" "$CLAUDE_CONFIG_DIR"
      if [ -f "$HOME/.codex/auth.json" ]; then
        ln -snf "$HOME/.codex/auth.json" "$CODEX_HOME/auth.json"
      fi
      rm -f "$CODEX_HOME/config.toml"

      ${envBlock}

      _server_url="http://127.0.0.1:${toString port}"
      _config_file="$OMNIGENT_CONFIG_HOME/config.yaml"
      if [ -f "$_config_file" ]; then
        if grep -q '^server:' "$_config_file"; then
          ${pkgs.gnused}/bin/sed -i.bak "s|^server:.*$|server: $_server_url|" "$_config_file"
        else
          printf '\nserver: %s\n' "$_server_url" >> "$_config_file"
        fi
      else
        printf 'server: %s\n' "$_server_url" > "$_config_file"
      fi

      exec ${self.packages.${system}.omnigent}/bin/omnigent server \
        --host 127.0.0.1 \
        --port ${toString port} \
        --database-uri "sqlite:///$OMNIGENT_DATA_DIR/chat.db" \
        --artifact-location "$OMNIGENT_DATA_DIR/artifacts" \
        --no-open
    '';

  omnigentPersonalServer = mkOmnigentServerScript "personal-default" 6767 ''
    ZAI_SECRET_PATH="${config.sops.secrets."zai".path}"
    MINIMAX_SECRET_PATH="${config.sops.secrets."minimax".path}"

    if [ -f "$ZAI_SECRET_PATH" ]; then
      export PERSONAL_ZAI_API_KEY="$(cat "$ZAI_SECRET_PATH")"
      export ZAI_API_KEY="$PERSONAL_ZAI_API_KEY"
    fi
    if [ -f "$MINIMAX_SECRET_PATH" ]; then
      export PERSONAL_MINIMAX_API_KEY="$(cat "$MINIMAX_SECRET_PATH")"
      export MINIMAX_API_KEY="$PERSONAL_MINIMAX_API_KEY"
    fi
  '';

  omnigentWorkServer = mkOmnigentServerScript "work-default" 6768 ''
    LUNAR_OPENAI_KEY_PATH="${config.sops.secrets."api/lunar/openai".path}"
    LUNAR_ANTHROPIC_KEY_PATH="${config.sops.secrets."api/lunar/anthropic".path}"

    if [ -f "$LUNAR_OPENAI_KEY_PATH" ]; then
      export LUNAR_OPENAI_API_KEY="$(cat "$LUNAR_OPENAI_KEY_PATH")"
      export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
      export OPENAI_BASE_URL="${workOpenAIBaseUrl}"
    fi
    if [ -f "$LUNAR_ANTHROPIC_KEY_PATH" ]; then
      export LUNAR_ANTHROPIC_API_KEY="$(cat "$LUNAR_ANTHROPIC_KEY_PATH")"
      export ANTHROPIC_API_KEY="$LUNAR_ANTHROPIC_API_KEY"
    fi
  '';

  mkOmnigentHostScript =
    profile: port: envBlock:
    pkgs.writeShellScript "omnigent-${profile}-host" ''
      set -euo pipefail

      export PATH="${omnigentVendorPath}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:$PATH"
      export OMNIGENT_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}/omnigent/profiles/${profile}"
      export OMNIGENT_DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/omnigent/profiles/${profile}"

      export CODEX_HOME="$OMNIGENT_CONFIG_HOME/codex-home"
      export CLAUDE_CONFIG_DIR="$OMNIGENT_CONFIG_HOME/claude-code"
      export OMNIGENT_CLAUDE_BIN="${pkgs.llm-agents.claude-code}/bin/claude"
      mkdir -p "$CODEX_HOME" "$CLAUDE_CONFIG_DIR"
      if [ -f "$HOME/.codex/auth.json" ]; then
        ln -snf "$HOME/.codex/auth.json" "$CODEX_HOME/auth.json"
      fi
      rm -f "$CODEX_HOME/config.toml"

      ${envBlock}

      _server_url="http://127.0.0.1:${toString port}"
      _i=0
      while [ "$_i" -lt 150 ]; do
        if ${pkgs.curl}/bin/curl -fsS "$_server_url/health" >/dev/null 2>&1; then
          exec ${self.packages.${system}.omnigent}/bin/omnigent host --server "$_server_url"
        fi
        _i=$((_i + 1))
        sleep 0.2
      done

      echo "timed out waiting for $_server_url before starting host" >&2
      exit 1
    '';

  omnigentPersonalHost = mkOmnigentHostScript "personal-default" 6767 ''
    ZAI_SECRET_PATH="${config.sops.secrets."zai".path}"
    MINIMAX_SECRET_PATH="${config.sops.secrets."minimax".path}"

    if [ -f "$ZAI_SECRET_PATH" ]; then
      export PERSONAL_ZAI_API_KEY="$(cat "$ZAI_SECRET_PATH")"
      export ZAI_API_KEY="$PERSONAL_ZAI_API_KEY"
    fi
    if [ -f "$MINIMAX_SECRET_PATH" ]; then
      export PERSONAL_MINIMAX_API_KEY="$(cat "$MINIMAX_SECRET_PATH")"
      export MINIMAX_API_KEY="$PERSONAL_MINIMAX_API_KEY"
    fi
  '';

  omnigentWorkHost = mkOmnigentHostScript "work-default" 6768 ''
    LUNAR_OPENAI_KEY_PATH="${config.sops.secrets."api/lunar/openai".path}"
    LUNAR_ANTHROPIC_KEY_PATH="${config.sops.secrets."api/lunar/anthropic".path}"

    if [ -f "$LUNAR_OPENAI_KEY_PATH" ]; then
      export LUNAR_OPENAI_API_KEY="$(cat "$LUNAR_OPENAI_KEY_PATH")"
      export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
      export OPENAI_BASE_URL="${workOpenAIBaseUrl}"
    fi
    if [ -f "$LUNAR_ANTHROPIC_KEY_PATH" ]; then
      export LUNAR_ANTHROPIC_API_KEY="$(cat "$LUNAR_ANTHROPIC_KEY_PATH")"
      export ANTHROPIC_API_KEY="$LUNAR_ANTHROPIC_API_KEY"
    fi
  '';
in
{
  options = {
    homeModules.claudeCode.enable = lib.mkEnableOption "enables claude code";
    homeModules.opencode.enable = lib.mkEnableOption "enables opencode";
    homeModules.codex.enable = lib.mkEnableOption "enables codex";
    homeModules.piCodingAgent.enable = lib.mkEnableOption "enables pi-coding-agent";
    homeModules.omnigent.enable = lib.mkEnableOption "enables omnigent";
    homeModules.openshell.enable = lib.mkEnableOption "enables openshell";
    homeModules.multica.enable = lib.mkEnableOption "enables multica";
  };

  config = {
    # --- sops secrets (shared across all ai tools) ---
    sops.secrets = lib.mkMerge [
      (lib.mkIf
        (
          config.homeModules.opencode.enable
          || config.homeModules.piCodingAgent.enable
          || config.homeModules.omnigent.enable
        )
        {
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
        }
      )
      (lib.mkIf
        (
          config.homeModules.claudeCode.enable
          || config.homeModules.opencode.enable
          || config.homeModules.piCodingAgent.enable
          || config.homeModules.codex.enable
          || config.homeModules.omnigent.enable
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

    launchd.agents = lib.mkIf (config.homeModules.omnigent.enable && pkgs.stdenv.isDarwin) {
      omnigent-personal = {
        enable = true;
        config = {
          Program = omnigentPersonalServer;
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/omnigent-personal.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/omnigent-personal.err.log";
        };
      };
      omnigent-personal-host = {
        enable = true;
        config = {
          Program = omnigentPersonalHost;
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/omnigent-personal-host.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/omnigent-personal-host.err.log";
        };
      };
      omnigent-work = {
        enable = true;
        config = {
          Program = omnigentWorkServer;
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/omnigent-work.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/omnigent-work.err.log";
        };
      };
      omnigent-work-host = {
        enable = true;
        config = {
          Program = omnigentWorkHost;
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/omnigent-work-host.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/omnigent-work-host.err.log";
        };
      };
    };

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
      (lib.mkIf config.homeModules.omnigent.enable [
        (pkgs.writeShellScriptBin "omnigent" ''
          set -euo pipefail

          export PATH="${omnigentVendorPath}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:$PATH"
          _omnigent_bin="${self.packages.${system}.omnigent}/bin/omnigent"
          _curl_bin="${pkgs.curl}/bin/curl"

          is_lunar_project() {
            case "$(pwd)" in
              "$HOME"/git/github.com/lunarway|"$HOME"/git/github.com/lunarway/*|"$HOME"/git/github.com/kirksw/lunar-notes|"$HOME"/git/github.com/kirksw/lunar-notes/*|"$HOME"/git/github.com/kirksw/lunarOS|"$HOME"/git/github.com/kirksw/lunarOS/*|"$HOME"/projects/lunar|"$HOME"/projects/lunar/*)
                return 0
                ;;
              *)
                return 1
                ;;
            esac
          }

          ensure_profile_server_config() {
            _server_url="http://127.0.0.1:$_omni_port"
            _config_file="$OMNIGENT_CONFIG_HOME/config.yaml"
            mkdir -p "$OMNIGENT_CONFIG_HOME"
            if [ -f "$_config_file" ]; then
              if grep -q '^server:' "$_config_file"; then
                ${pkgs.gnused}/bin/sed -i.bak "s|^server:.*$|server: $_server_url|" "$_config_file"
              else
                printf '\nserver: %s\n' "$_server_url" >> "$_config_file"
              fi
            else
              printf 'server: %s\n' "$_server_url" > "$_config_file"
            fi
          }

          ensure_profile_server_running() {
            _server_url="http://127.0.0.1:$_omni_port"
            if "$_curl_bin" -fsS "$_server_url/health" >/dev/null 2>&1; then
              return 0
            fi

            mkdir -p "$OMNIGENT_DATA_DIR/artifacts" "$OMNIGENT_DATA_DIR/logs"
            nohup "$_omnigent_bin" server \
              --host 127.0.0.1 \
              --port "$_omni_port" \
              --database-uri "sqlite:///$OMNIGENT_DATA_DIR/chat.db" \
              --artifact-location "$OMNIGENT_DATA_DIR/artifacts" \
              --no-open \
              > "$OMNIGENT_DATA_DIR/logs/server.log" 2>&1 &

            _i=0
            while [ "$_i" -lt 50 ]; do
              if "$_curl_bin" -fsS "$_server_url/health" >/dev/null 2>&1; then
                return 0
              fi
              _i=$((_i + 1))
              sleep 0.2
            done

            echo "failed to start profile-local omnigent server at $_server_url" >&2
            echo "see $OMNIGENT_DATA_DIR/logs/server.log" >&2
            return 1
          }

          ZAI_SECRET_PATH="${config.sops.secrets."zai".path}"
          MINIMAX_SECRET_PATH="${config.sops.secrets."minimax".path}"
          LUNAR_OPENAI_KEY_PATH="${config.sops.secrets."api/lunar/openai".path}"
          LUNAR_ANTHROPIC_KEY_PATH="${config.sops.secrets."api/lunar/anthropic".path}"

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

          _omni_profile=""
          _d="$PWD"
          while [ "$_d" != "/" ] && [ -n "$_d" ]; do
            if [ -f "$_d/.nix-agents-profile" ]; then
              _omni_profile="$(cat "$_d/.nix-agents-profile")"
              break
            fi
            _d="''${_d%/*}"
          done
          if [ -z "$_omni_profile" ]; then
            if is_lunar_project; then
              _omni_profile="work-default"
            else
              _omni_profile="personal-default"
            fi
          fi
          case "$_omni_profile" in
            personal-default|work-default) ;;
            *) _omni_profile="personal-default" ;;
          esac

          export OMNIGENT_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}/omnigent/profiles/$_omni_profile"
          export OMNIGENT_DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/omnigent/profiles/$_omni_profile"
          export CODEX_HOME="$OMNIGENT_CONFIG_HOME/codex-home"
          mkdir -p "$CODEX_HOME"
          if [ -f "$HOME/.codex/auth.json" ]; then
            ln -snf "$HOME/.codex/auth.json" "$CODEX_HOME/auth.json"
          fi
          rm -f "$CODEX_HOME/config.toml"

          case "$_omni_profile" in
            work-default)
              _omni_port=6768
              if [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
                export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
                export OPENAI_BASE_URL="${workOpenAIBaseUrl}"
              fi
              if [ -n "''${LUNAR_ANTHROPIC_API_KEY:-}" ]; then
                export ANTHROPIC_API_KEY="$LUNAR_ANTHROPIC_API_KEY"
              fi
              ;;
            *)
              _omni_port=6767
              if [ -n "''${PERSONAL_ZAI_API_KEY:-}" ]; then
                export ZAI_API_KEY="$PERSONAL_ZAI_API_KEY"
              fi
              if [ -n "''${PERSONAL_MINIMAX_API_KEY:-}" ]; then
                export MINIMAX_API_KEY="$PERSONAL_MINIMAX_API_KEY"
              fi
              ;;
          esac

          case "''${1:-}" in
            server)
              case "''${2:-}" in
                start|status|stop)
                  ensure_profile_server_config
                  if [ "''${2:-}" = start ]; then
                    ensure_profile_server_running
                    echo "profile-local omnigent server running at http://127.0.0.1:$_omni_port"
                    exit 0
                  elif [ "''${2:-}" = status ]; then
                    if "$_curl_bin" -fsS "http://127.0.0.1:$_omni_port/health" >/dev/null 2>&1; then
                      echo "profile-local omnigent server running at http://127.0.0.1:$_omni_port"
                    else
                      echo "profile-local omnigent server not running"
                      exit 1
                    fi
                    exit 0
                  else
                    exec "$_omnigent_bin" "$@"
                  fi
                  ;;
              esac
              ;;
          esac

          ensure_profile_server_config
          ensure_profile_server_running

          exec "$_omnigent_bin" "$@"
        '')
        (pkgs.writeShellScriptBin "omni" ''
          exec "${config.home.profileDirectory}/bin/omnigent" "$@"
        '')
      ])
      (lib.mkIf config.homeModules.multica.enable [
        self.packages.${system}.multica
      ])
      (lib.mkIf config.homeModules.openshell.enable [
        inputs.nix-agents.packages.${system}.openshell
      ])
    ];

  };
}
