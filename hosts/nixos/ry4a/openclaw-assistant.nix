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

    modelFallbacks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "router-openai/cx/gpt-5.4"
        "router-anthropic/glm/glm-5.2"
      ];
      description = "Fallback models for the assistant default agent model.";
    };
  };

  config = {
    virtualisation.docker.enable = true;
    environment.systemPackages = [ pkgs.openclaw ];
    users.users.agent.extraGroups = [
      "docker"
      "keys"
    ];

    # Build the sandbox image used for non-main/spawned agent work.
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
      servicePath = [
        pkgs.docker
        pkgs.sudo
        pkgs.tailscale
      ];
      config = {
        gateway = {
          mode = "local";
          # Tailscale Serve publishes the loopback gateway to the tailnet with Tailscale identity headers.
          bind = "loopback";
          tailscale = {
            mode = "serve";
            resetOnExit = false;
          };
          # Tailscale Serve maps the dashboard to https://<node>.<tailnet> (443).
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
        commands.ownerAllowFrom = map (id: "telegram:${toString id}") cfg.telegramAllowFrom;
        browser = {
          enabled = true;
          executablePath = "${pkgs.chromium}/bin/chromium";
          headless = true;
          noSandbox = true;
          extraArgs = [ "--disable-dev-shm-usage" ];
        };
        memory = {
          backend = "qmd";
          citations = "auto";
          qmd = {
            command = "${pkgs.qmd}/bin/qmd";
            includeDefaultMemory = true;
            sessions = {
              enabled = true;
              exportDir = "/var/lib/openclaw/session-memory";
              retentionDays = 90;
            };
            update = {
              onBoot = true;
              startup = "idle";
              interval = "10m";
              embedInterval = "30m";
              waitForBootSync = false;
            };
          };
        };
        plugins.entries.memory-core = {
          enabled = true;
          config.dreaming.enabled = true;
        };
        plugins.entries.file-transfer = {
          enabled = true;
          config.nodes."*" = {
            ask = "on-miss";
            allowReadPaths = [
              "/srv/assistant/**"
              "/var/lib/openclaw/logs/**"
              "/etc/assistant/**"
              "/etc/openclaw/openclaw.json"
              "/Users/kisw/git/**"
              "/Users/kisw/Desktop/**"
              "/Users/kisw/Downloads/**"
              "/tmp/openclaw-transfer/**"
            ];
            allowWritePaths = [
              "/srv/assistant/inbox/**"
              "/srv/assistant/workspace/**"
              "/Users/kisw/Downloads/openclaw-transfer/**"
              "/tmp/openclaw-transfer/**"
            ];
            denyPaths = [
              "/run/host-secrets/**"
              "/run/secrets/**"
              "/var/lib/openclaw/config/**"
              "/Users/*/.ssh/**"
              "/Users/*/.gnupg/**"
              "/Users/*/.config/sops/**"
              "/Users/*/Library/Keychains/**"
            ];
            maxBytes = 16777216;
            followSymlinks = false;
          };
        };
        models.providers = {
          router-anthropic = {
            baseUrl = "http://${cfg.router}:80";
            api = "anthropic-messages";
            apiKey = {
              source = "env";
              provider = "default";
              id = "LLM_ROUTER_API_KEY";
            };
            models = [
              {
                id = "minimax/MiniMax-M3";
                name = "MiniMax M3";
                api = "anthropic-messages";
                contextWindow = 1000000;
                maxTokens = 524288;
                reasoning = true;
                input = [
                  "text"
                  "image"
                  "video"
                ];
              }
              {
                id = "minimax/MiniMax-M2.7-highspeed";
                name = "MiniMax M2.7 Highspeed";
                api = "anthropic-messages";
                contextWindow = 204800;
                maxTokens = 204800;
                reasoning = true;
              }
              # home-llm-router currently exposes GLM as glm/*, not zai/*.
              {
                id = "glm/glm-5.2";
                name = "GLM 5.2";
                api = "anthropic-messages";
                contextWindow = 1000000;
                maxTokens = 131072;
                reasoning = true;
              }
              {
                id = "glm/glm-4.6v";
                name = "GLM 4.6V";
                api = "anthropic-messages";
                contextWindow = 128000;
                maxTokens = 131072;
                input = [
                  "text"
                  "image"
                ];
              }
            ];
          };
          router-openai = {
            baseUrl = "http://${cfg.router}:80/v1";
            api = "openai-completions";
            apiKey = {
              source = "env";
              provider = "default";
              id = "LLM_ROUTER_API_KEY";
            };
            models = [
              {
                id = "cx/gpt-5.3-codex";
                name = "GPT 5.3 Codex";
                api = "openai-completions";
              }
              {
                id = "cx/gpt-5.4";
                name = "GPT 5.4";
                api = "openai-completions";
              }
              {
                id = "cx/gpt-5.5";
                name = "GPT 5.5";
                api = "openai-completions";
                reasoning = true;
              }
            ];
          };
        };
        agents.defaults = {
          model = {
            primary = "router-anthropic/minimax/MiniMax-M3";
            fallbacks = cfg.modelFallbacks;
          };
          # ponytail: hide model chain-of-thought; turn back on only if answer quality tanks.
          thinkingDefault = "off";
          reasoningDefault = "off";
          sandbox = {
            # Docker sandbox is available, but sessions are not forced into it.
            mode = "off";
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

    systemd.services.openclaw-tailscale-operator = {
      description = "Allow OpenClaw to manage Tailscale Serve";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      before = [ "openclaw-gateway.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
          if ${pkgs.tailscale}/bin/tailscale status --json >/dev/null 2>&1; then
            ${pkgs.tailscale}/bin/tailscale set --operator=agent || true
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
      '';
    };

    # Ensure secrets-env runs before gateway
    systemd.services.openclaw-gateway = {
      after = [
        "openclaw-secrets-env.service"
        "openclaw-sandbox-image.service"
        "openclaw-tailscale-operator.service"
      ];
      wants = [
        "openclaw-secrets-env.service"
        "openclaw-sandbox-image.service"
        "openclaw-tailscale-operator.service"
      ];
    };
  };
}
