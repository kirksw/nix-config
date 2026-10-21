{
  pkgs,
  self,
  inputs,
  lib,
  config,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  baseSettings = import ../../../agents/base-settings.nix {
    inherit self system;
    inherit (pkgs) lib;
  };
  assets = (import ../../../agents { inherit pkgs inputs; }).profileMeta.personal-fallback.storePath;
  piDir = "${config.home.homeDirectory}/.config/nix-agents/pi/bases/personal/profiles/personal-fallback";
  settings = builtins.toJSON {
    defaultProvider = "litellm";
    defaultModel = "openai/gpt-6-sol";
    defaultThinkingLevel = "medium";
    packages = [ "${self}/agents/packages/pi-litellm-provider" ];
  };
  pi = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail
    export LITELLM_API_KEY="$(cat ${config.sops.secrets."api/litellm/api-key".path})"
    export LITELLM_CF_ACCESS_CLIENT_ID="$(cat ${config.sops.secrets."api/litellm/cf-client-id".path})"
    export LITELLM_CF_ACCESS_CLIENT_SECRET="$(cat ${
      config.sops.secrets."api/litellm/cf-client-secret".path
    })"
    export PI_CODING_AGENT_DIR=${pkgs.lib.escapeShellArg piDir}
    exec ${self.packages.${system}.pi}/bin/pi "$@"
  '';
in
{
  home = {
    stateVersion = "24.05";
    activation.sops-nix = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] "");
    packages = with pkgs; [
      pi
      git
      gh
      openssh
      ripgrep
      fd
      jq
      tmux
      neovim
      nodejs_22
      python3
      go
      self.packages.${pkgs.stdenv.hostPlatform.system}.codex
    ];
  };
  programs.home-manager.enable = true;
  launchd.agents.sops-nix.domain = "user";
  sops.age.keyFile = "${config.home.homeDirectory}/.config/age/keys.txt";
  sops.secrets = {
    "api/litellm/api-key" = {
      sopsFile = "${self}/secrets/api/litellm.yaml";
      key = "api-key";
    };
    "api/litellm/cf-client-id" = {
      sopsFile = "${self}/secrets/api/litellm.yaml";
      key = "cf-client-id";
    };
    "api/litellm/cf-client-secret" = {
      sopsFile = "${self}/secrets/api/litellm.yaml";
      key = "cf-client-secret";
    };
  };
  xdg.configFile = {
    "nix-agents/pi/bases/personal/profiles/personal-fallback/settings.json".text = settings;
    "nix-agents/pi/bases/personal/profiles/personal-fallback/models.json".text =
      baseSettings.targets.pi.personal."models.json";
    "nix-agents/pi/bases/personal/profiles/personal-fallback/AGENTS.md".source = "${assets}/AGENTS.md";
    "nix-agents/pi/bases/personal/profiles/personal-fallback/skills".source = "${assets}/skills";
    "nix-agents/pi/bases/personal/profiles/personal-fallback/extensions".source =
      "${assets}/extensions";
    "nix-agents/pi/bases/personal/profiles/personal-fallback/prompts".source = "${assets}/prompts";
  };
}
