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
      description = "Host-side sops directory shared via virtiofs to /run/host-secrets/openclaw.";
    };
  };

  config = {
    # --- Docker for sandboxed tool execution ---
    virtualisation.docker.enable = true;
    users.users.agent.extraGroups = [ "docker" ];

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
          token = {
            source = "env";
            provider = "default";
            id = "TELEGRAM_BOT_TOKEN";
          };
        };
      };

      # Build env file from shared sops secrets before starting.
      execStartPre = [
        ''${pkgs.coreutils}/bin/install -d -m 0700 /run/openclaw-secrets''
        (
          ''${pkgs.bash}/bin/bash -c 'umask 077; ''
          + ''echo "TELEGRAM_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/telegram_bot_token)" ''
          + ''     "LLM_ROUTER_API_KEY=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/llm_router_api_key)" ''
          + ''     "GATEWAY_TOKEN=$(${pkgs.coreutils}/bin/cat ${cfg.sopsDir}/gateway_token)" ''
          + ''> /run/openclaw-secrets/env' ''
        )
      ];
      environmentFiles = [ "-/run/openclaw-secrets/env" ];
    };

    # Allow gateway port on Tailscale interface
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 18789 ];
  };
}
