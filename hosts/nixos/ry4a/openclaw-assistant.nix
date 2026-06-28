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
  };

  config = {
    # --- Docker for sandboxed tool execution ---
    virtualisation.docker.enable = true;
    users.users.agent.extraGroups = [
      "docker"
      "keys"
    ];

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

      config = {
        gateway = {
          mode = "local";
          auth = {
            mode = "token";
            token = {
              source = "env";
              provider = "default";
              id = "GATEWAY_TOKEN";
            };
          };
        };
        models.providers.openai = {
          baseUrl = "http://${cfg.router}:80/v1";
          apiKey = {
            source = "env";
            provider = "default";
            id = "LLM_ROUTER_API_KEY";
          };
        };
        agents.defaults.sandbox = {
          mode = "all";
          backend = "docker";
        };
        channels.telegram = {
          enabled = true;
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
      after = [ "openclaw-secrets-env.service" ];
      wants = [ "openclaw-secrets-env.service" ];
    };

    # Allow gateway port on Tailscale interface
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 18789 ];
  };
}
