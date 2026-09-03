# OpenClaw gateway configuration for assistant microVMs.
# Imported into a VM config when the assistant definition has `openclaw.router` set.
{
  self,
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

    providerMode = lib.mkOption {
      type = lib.types.enum [
        "router"
        "direct"
        "litellm"
      ];
      default = "router";
      description = "Whether this assistant uses the local router, direct providers, or private LiteLLM.";
    };

    modelPrimary = lib.mkOption {
      type = lib.types.str;
      default = "router-anthropic/minimax/MiniMax-M3";
      description = "Default model identifier for this assistant.";
    };

    modelAllowlist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "The complete model allowlist when non-empty.";
    };

    thinkingDefault = lib.mkOption {
      type = lib.types.str;
      default = "off";
      description = "Default thinking level for supported models.";
    };

    reasoningDefault = lib.mkOption {
      type = lib.types.enum [
        "on"
        "off"
        "stream"
      ];
      default = "off";
      description = "Default reasoning visibility.";
    };

    sopsDir = lib.mkOption {
      type = lib.types.str;
      description = "virtiofs-mounted sops secrets directory readable by the keys group.";
    };

    sherpaRuntimeDir = lib.mkOption {
      type = lib.types.path;
      description = "Pinned Sherpa-ONNX runtime directory for the local TTS skill.";
    };

    sherpaModelDir = lib.mkOption {
      type = lib.types.path;
      description = "Pinned Sherpa-ONNX voice model directory for the local TTS skill.";
    };

    telegramAllowFrom = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = "Telegram user IDs allowed to message this assistant.";
    };

    modelFallbacks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "router-anthropic/glm/glm-5.2" ];
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
      "d /srv/assistant/inbox 0755 agent users -"
      "d /srv/assistant/workspace/.tmp 0700 agent users -"
      "d /tmp/openclaw 0700 agent users -"
      "L+ /tmp/openclaw-transfer - - - - /tmp/openclaw"
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
          echo "GATEWAY_TOKEN=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/gateway_token)"
          if [ -f ${cfg.sopsDir}/llm_router_api_key ]; then
            echo "LLM_ROUTER_API_KEY=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/llm_router_api_key)"
          fi
          if [ -f ${cfg.sopsDir}/litellm_api_key ]; then
            echo "LITELLM_API_KEY=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/litellm_api_key)"
          fi
          if [ -f ${cfg.sopsDir}/minimax_api_key ]; then
            echo "MINIMAX_CODE_PLAN_KEY=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/minimax_api_key)"
          fi
          if [ -f ${cfg.sopsDir}/zai_api_key ]; then
            echo "ZAI_API_KEY=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/zai_api_key)"
          fi
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
        self.packages.${pkgs.system}.gifgrep
        cfg.sherpaRuntimeDir
        pkgs.docker
        pkgs.github-cli
        pkgs.openai-whisper
        pkgs.poppler-utils
        pkgs.qpdf
        pkgs.sudo
        pkgs.tailscale
        pkgs.tesseract
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
            allowedOrigins = [ "https://${config.networking.hostName}.tail54de03.ts.net" ];
            allowInsecureAuth = false;
            dangerouslyDisableDeviceAuth = false;
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
        plugins.entries.memory-wiki = {
          enabled = true;
        };
        skills = {
          allowBundled = [
            "camsnap"
            "clawhub"
            "diagram-maker"
            "gh-issues"
            "gifgrep"
            "github"
            "gog"
            "healthcheck"
            "meme-maker"
            "node-connect"
            "node-inspect-debugger"
            "notion"
            "openai-whisper"
            "python-debugpy"
            "session-logs"
            "sherpa-onnx-tts"
            "skill-creator"
            "sonoscli"
            "spike"
            "summarize"
            "taskflow"
            "taskflow-inbox-triage"
            "video-frames"
            "weather"
          ];
          entries = {
            gifgrep.enabled = true;
            github.enabled = true;
            openai-whisper.enabled = true;
            sherpa-onnx-tts = {
              enabled = true;
              env = {
                SHERPA_ONNX_RUNTIME_DIR = "${cfg.sherpaRuntimeDir}";
                SHERPA_ONNX_MODEL_DIR = "${cfg.sherpaModelDir}";
              };
            };
          };
        };
        messages.tts = {
          auto = "off";
          provider = "minimax";
          providers = {
            minimax = {
              model = "speech-2.8-hd";
              speakerVoiceId = "English_expressive_narrator";
              speed = 1.0;
              vol = 1.0;
            };
            "tts-local-cli" = {
              command = "${cfg.sherpaRuntimeDir}/bin/sherpa-onnx-offline-tts";
              args = [
                "--vits-model=${cfg.sherpaModelDir}/en_US-lessac-high.onnx"
                "--vits-tokens=${cfg.sherpaModelDir}/tokens.txt"
                "--vits-data-dir=${cfg.sherpaModelDir}/espeak-ng-data"
                "--output-filename={{OutputPath}}"
                "{{Text}}"
              ];
              outputFormat = "wav";
              timeoutMs = 120000;
            };
          };
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
              "/tmp/openclaw/**"
              "/tmp/openclaw-transfer/**"
            ];
            allowWritePaths = [
              "/srv/assistant/inbox/**"
              "/srv/assistant/workspace/**"
              "/Users/kisw/Downloads/openclaw-transfer/**"
              "/tmp/openclaw/**"
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
        models.mode = "replace";
        models.providers =
          if cfg.providerMode == "litellm" then
            {
              litellm = {
                # NodePort is reachable only through the k3s node's tailnet address.
                baseUrl = "http://nixos-ry6a.tail54de03.ts.net:31400/v1";
                api = "openai-completions";
                apiKey = {
                  source = "env";
                  provider = "default";
                  id = "LITELLM_API_KEY";
                };
                models = [
                  {
                    id = "openai/gpt-5.5";
                    name = "GPT-5.5";
                    contextWindow = 272000;
                    maxTokens = 128000;
                    reasoning = true;
                  }
                  {
                    id = "openai/gpt-5.6-sol";
                    name = "GPT-5.6 Sol";
                    contextWindow = 272000;
                    maxTokens = 128000;
                    reasoning = true;
                  }
                  {
                    id = "openai/gpt-5.6-terra";
                    name = "GPT-5.6 Terra";
                    contextWindow = 272000;
                    maxTokens = 128000;
                    reasoning = true;
                  }
                  {
                    id = "openai/gpt-5.6-luna";
                    name = "GPT-5.6 Luna";
                    contextWindow = 272000;
                    maxTokens = 128000;
                    reasoning = true;
                  }
                  {
                    id = "minimax-m2";
                    name = "MiniMax M2";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "minimax-m2.1";
                    name = "MiniMax M2.1";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "minimax-m2.1-highspeed";
                    name = "MiniMax M2.1 Highspeed";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "minimax-m2.5";
                    name = "MiniMax M2.5";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "minimax-m2.5-highspeed";
                    name = "MiniMax M2.5 Highspeed";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "minimax-m2.7";
                    name = "MiniMax M2.7";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "minimax-m2.7-highspeed";
                    name = "MiniMax M2.7 Highspeed";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "minimax-m3";
                    name = "MiniMax M3";
                    contextWindow = 1000000;
                    maxTokens = 131072;
                    reasoning = true;
                    input = [
                      "text"
                      "image"
                    ];
                  }
                  {
                    id = "glm-4.5";
                    name = "GLM 4.5";
                    contextWindow = 131072;
                    maxTokens = 98304;
                    reasoning = true;
                  }
                  {
                    id = "glm-4.5-air";
                    name = "GLM 4.5 Air";
                    contextWindow = 131072;
                    maxTokens = 98304;
                    reasoning = true;
                  }
                  {
                    id = "glm-4.6";
                    name = "GLM 4.6";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-4.7";
                    name = "GLM 4.7";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5";
                    name = "GLM 5";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5-turbo";
                    name = "GLM 5 Turbo";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5.1";
                    name = "GLM 5.1";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5.2";
                    name = "GLM 5.2";
                    contextWindow = 1000000;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5.3";
                    name = "GLM 5.3";
                    contextWindow = 1000000;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5.3-flash";
                    name = "GLM 5.3 Flash";
                    contextWindow = 1000000;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                ];
              };
            }
          else if cfg.providerMode == "direct" then
            {
              minimax = {
                baseUrl = "https://api.minimax.io/v1";
                api = "openai-completions";
                apiKey = {
                  source = "env";
                  provider = "default";
                  id = "MINIMAX_CODE_PLAN_KEY";
                };
                models = [
                  {
                    id = "MiniMax-M3";
                    name = "MiniMax M3";
                    contextWindow = 1000000;
                    maxTokens = 131072;
                    reasoning = true;
                    input = [
                      "text"
                      "image"
                    ];
                  }
                  {
                    id = "MiniMax-M2.7";
                    name = "MiniMax M2.7";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "MiniMax-M2.7-highspeed";
                    name = "MiniMax M2.7 Highspeed";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "MiniMax-M2.5";
                    name = "MiniMax M2.5";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "MiniMax-M2.5-highspeed";
                    name = "MiniMax M2.5 Highspeed";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "MiniMax-M2.1";
                    name = "MiniMax M2.1";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "MiniMax-M2.1-highspeed";
                    name = "MiniMax M2.1 Highspeed";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "MiniMax-M2";
                    name = "MiniMax M2";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                ];
              };

              zai = {
                baseUrl = "https://api.z.ai/api/coding/paas/v4/";
                api = "openai-completions";
                apiKey = {
                  source = "env";
                  provider = "default";
                  id = "ZAI_API_KEY";
                };
                models = [
                  {
                    id = "glm-5.3";
                    name = "GLM 5.3";
                    contextWindow = 1000000;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5.2";
                    name = "GLM 5.2";
                    contextWindow = 1000000;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5.1";
                    name = "GLM 5.1";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5";
                    name = "GLM 5";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-5-turbo";
                    name = "GLM 5 Turbo";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-4.7";
                    name = "GLM 4.7";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-4.6";
                    name = "GLM 4.6";
                    contextWindow = 204800;
                    maxTokens = 131072;
                    reasoning = true;
                  }
                  {
                    id = "glm-4.5";
                    name = "GLM 4.5";
                    contextWindow = 131072;
                    maxTokens = 98304;
                    reasoning = true;
                  }
                  {
                    id = "glm-4.5-air";
                    name = "GLM 4.5 Air";
                    contextWindow = 131072;
                    maxTokens = 98304;
                    reasoning = true;
                  }
                ];
              };
            }
          else
            {
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
            };
        agents.defaults = {
          workspace = "/srv/assistant/workspace";
          model = {
            primary = cfg.modelPrimary;
            fallbacks = cfg.modelFallbacks;
          };
          thinkingDefault = cfg.thinkingDefault;
          reasoningDefault = cfg.reasoningDefault;
          sandbox = {
            # Docker sandbox is available, but sessions are not forced into it.
            mode = "off";
            backend = "docker";
          };
        }
        // lib.optionalAttrs (cfg.modelAllowlist != [ ]) {
          models = lib.genAttrs cfg.modelAllowlist (_: { });
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
      environment = {
        TMPDIR = "/srv/assistant/workspace/.tmp";
        TMP = "/srv/assistant/workspace/.tmp";
        TEMP = "/srv/assistant/workspace/.tmp";
      };
      execStartPre = [ "${pkgs.coreutils}/bin/chmod 700 /var/lib/openclaw" ];
      # ponytail: use the module option instead of fighting systemd.serviceConfig later.
      workingDirectory = "/srv/assistant/workspace";
    };

    environment.etc."openclaw/openclaw.json" = {
      mode = lib.mkForce "0600";
      user = "agent";
      group = "users";
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
