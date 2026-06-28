# OpenClaw gateway configuration for assistant microVMs.
# Imported into a VM config when the assistant definition has `openclaw.router` set.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.assistant.openclaw;
in
{
  options.assistant.openclaw = {
    router = lib.mkOption {
      type = lib.types.str;
      description = "Hostname of the LLM router VM (Tailscale name).";
    };

    sopsDir = lib.mkOption {
      type = lib.types.str;
      description = "virtiofs-mounted sops secrets directory readable by the keys group.";
    };

    telegramAllowFrom = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = "Telegram user IDs allowed to message this assistant.";
    };
  };

  config = {
    # --- Docker for sandboxed tool execution ---
    virtualisation.docker.enable = true;
    users.users.agent.extraGroups = [
      "docker"
      "keys"
    ];

    # --- Build the OpenClaw sandbox Docker image on first boot ---
    # OpenClaw requires openclaw-sandbox:bookworm-slim to exist before
    # it can sandbox tool execution. This builds it from debian:bookworm-slim
    # with python3 and basic tools baked in.
    systemd.services.openclaw-sandbox-image = {
      description = "Build OpenClaw sandbox Docker image";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if ! ${pkgs.docker}/bin/docker image inspect openclaw-sandbox:bookworm-slim >/dev/null 2>&1; then
          echo "Building openclaw-sandbox:bookworm-slim..."
          ${pkgs.docker}/bin/docker build -t openclaw-sandbox:bookworm-slim - <<'DOCKERFILE'
        FROM debian:bookworm-slim
        ENV DEBIAN_FRONTEND=noninteractive
        RUN apt-get update && apt-get install -y --no-install-recommends \
          bash ca-certificates curl git jq python3 ripgrep \
          && rm -rf /var/lib/apt/lists/*
        RUN useradd --create-home --shell /bin/bash sandbox
        USER sandbox
        WORKDIR /home/sandbox
        CMD ["sleep", "infinity"]
        DOCKERFILE
          echo "Done."
        else
          echo "openclaw-sandbox:bookworm-slim already exists, skipping."
        fi
      '';
    };

    # Runtime dir for the assembled env file
    systemd.tmpfiles.rules = [
      "d /run/openclaw-secrets 0700 agent users -"
    ];

    # --- Root pre-start: assemble env file from virtiofs sops secrets ---
    # Runs as root because the sops files are 0440 root:keys, and systemd ExecStartPre
    # inherits the service User (agent). This unit writes a file the agent can read.
    systemd.services.openclaw-secrets-env = {
      description = "Assemble OpenClaw env file from sops secrets";
      before = [ "openclaw-gateway.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        umask 077
        ${pkgs.coreutils}/bin/install -d -m 0700 /run/openclaw-secrets
        {
          echo "TELEGRAM_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/telegram_bot_token)"
          echo "LLM_ROUTER_API_KEY=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/llm_router_api_key)"
          echo "GATEWAY_TOKEN=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/gateway_token)"
        } > /run/openclaw-secrets/env
        ${pkgs.coreutils}/bin/chown agent:users /run/openclaw-secrets/env
      '';
    };

    # --- OpenClaw gateway ---
    services.openclaw-gateway = {
      enable = true;
      createUser = false;
      user = "agent";
      group = "users";
      stateDir = "/var/lib/openclaw";
      port = 18789;
      # Docker sandbox needs the docker binary in the gateway's PATH
      servicePath = [ pkgs.docker ];

      config = {
        gateway = {
          mode = "local";
          # Bind on all interfaces so the dashboard is reachable over Tailscale
          bind = "lan";
          # Allow dashboard WebSocket connections from Tailscale hostnames and IPs
          # Trust nginx reverse proxy forwarding headers
          trustedProxies = [ "127.0.0.1/32" ];
          controlUi = {
            allowedOrigins = [
              "http://${cfg.router}"
              "http://kirk-assistant"
              "http://sanja-assistant"
              "http://household-assistant"
              "http://100.123.43.18"
              "http://100.67.143.125"
              "http://100.82.155.69"
            ];
            # Allow plain HTTP device auth since we're behind a trusted tailnet
            allowInsecureAuth = true;
            # Device auth requires crypto.subtle which needs HTTPS.
            # We have gateway token auth + trusted tailnet, so disable device auth.
            dangerouslyDisableDeviceAuth = true;
          };
          # Trust Tailscale identity so dashboard access doesn't need token auth on tailnet
          auth = {
            mode = "token";
            allowTailscale = true;
            token = {
              source = "env";
              provider = "default";
              id = "GATEWAY_TOKEN";
            };
          };
        };
        models.providers = {
          cx = {
            baseUrl = "http://${cfg.router}:80/v1";
            apiKey = {
              source = "env";
              provider = "default";
              id = "LLM_ROUTER_API_KEY";
            };
          };
          minimax = {
            baseUrl = "http://${cfg.router}:80/v1";
            apiKey = {
              source = "env";
              provider = "default";
              id = "LLM_ROUTER_API_KEY";
            };
          };
          glm = {
            baseUrl = "http://${cfg.router}:80/v1";
            apiKey = {
              source = "env";
              provider = "default";
              id = "LLM_ROUTER_API_KEY";
            };
          };
        };
        agents.defaults = {
          model = {
            primary = "minimax/MiniMax-M3";
            fallbacks = [
              "cx/gpt-5.5"
              "glm/glm-5.2"
            ];
          };
          sandbox = {
            mode = "all";
            backend = "docker";
          };
        };
        channels.telegram = {
          enabled = true;
          allowFrom = cfg.telegramAllowFrom;
          botToken = {
            source = "env";
            provider = "default";
            id = "TELEGRAM_BOT_TOKEN";
          };
        };
      };

      environmentFiles = [ "/run/openclaw-secrets/env" ];
    };

    # Ensure secrets-env runs before gateway
    systemd.services.openclaw-gateway = {
      after = [
        "openclaw-secrets-env.service"
        "openclaw-sandbox-image.service"
      ];
      wants = [
        "openclaw-secrets-env.service"
        "openclaw-sandbox-image.service"
      ];
    };

    # Allow gateway port on Tailscale interface
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      18789
      80
    ];

    # Reverse proxy port 80 -> gateway 18789 for easy dashboard access
    # Includes WebSocket upgrade support for the dashboard UI
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts."_" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:18789";
          proxyWebsockets = true;
        };
      };
    };
  };
}
