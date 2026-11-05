{
  self,
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  homeDir = config.home.homeDirectory;
  piDir = "${homeDir}/.config/nix-agents/pi/bases/personal/profiles/personal-fallback";
  assets = (import ../../../agents { inherit pkgs inputs; }).profileMeta.personal-fallback.storePath;
  baseSettings = import ../../../agents/base-settings.nix {
    inherit self system;
    inherit (pkgs) lib;
  };
  pi = pkgs.writeShellScriptBin "pi" ''
    set -euo pipefail
    export LITELLM_API_KEY="$(cat ${config.sops.secrets."api/litellm/api-key".path})"
    export LITELLM_CF_ACCESS_CLIENT_ID="$(cat ${config.sops.secrets."api/litellm/cf-client-id".path})"
    export LITELLM_CF_ACCESS_CLIENT_SECRET="$(cat ${
      config.sops.secrets."api/litellm/cf-client-secret".path
    })"
    export PI_CODING_AGENT_DIR=${lib.escapeShellArg piDir}
    exec ${self.packages.${system}.pi}/bin/pi "$@"
  '';
  piSettings = builtins.toJSON {
    defaultProvider = "litellm";
    defaultModel = "openai/gpt-6-sol";
    defaultThinkingLevel = "medium";
    packages = [ "${self}/agents/packages/pi-litellm-provider" ];
  };
in
{
  home = {
    stateVersion = "24.05";
    activation.sops-nix = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] "");
    packages = with pkgs; [
      pi
      gh
      lazygit
      inputs.ezgit.packages.${system}.default
      gitmux
      jq
      yq
      gum
      curl
      pet
      devenv
      duckdb
      nodejs_22
      python3
      go
      zig
      rustup
      sops
      kubectl
      k9s
      kubernetes-helm
      kustomize
      fluxcd
      kubeconform
      kubectl-slice
      self.packages.${system}.codex
      self.packages.${system}.claude-code
    ];
    sessionVariables = {
      LANG = "en_US.UTF-8";
      KUBECONFIG = config.sops.secrets."k8s/homelab".path;
      SOPS_AGE_KEY_FILE = "${homeDir}/.config/age/keys.txt";
    };
  };

  programs = {
    home-manager.enable = true;
    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = builtins.fromTOML (builtins.readFile "${self}/config/zsh/starship/presets/pure.toml");
    };
    fzf.enable = true;
    zoxide.enable = true;
    yazi = {
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "yy";
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        user.useConfigOnly = true;
      };
      includes = [ { path = config.sops.templates."git-kirksw".path; } ];
    };
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."github.com-kirksw" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = config.sops.secrets."ssh/kirksw/private".path;
        IdentitiesOnly = true;
      };
    };
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
    };
  };

  homeModules = {
    appearanceSync.enable = true;
    neovim.enable = true;
    tmux.enable = true;
    ghostty.enable = true;
    wezterm.enable = true;
    cmux.enable = true;
  };

  launchd.agents.sops-nix.domain = "user";
  sops = {
    age.keyFile = "${homeDir}/.config/age/keys.txt";
    secrets = {
      "k8s/homelab" = {
        sopsFile = "${self}/secrets/k8s/homelab.yaml";
        key = "config";
        mode = "0400";
      };
      "git/kirksw/name" = {
        sopsFile = "${self}/secrets/git/kirksw.yaml";
        key = "name";
      };
      "git/kirksw/email" = {
        sopsFile = "${self}/secrets/git/kirksw.yaml";
        key = "email";
      };
      "ssh/kirksw/private" = {
        sopsFile = "${self}/secrets/ssh/kirksw.yaml";
        key = "private";
        mode = "0400";
      };
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
    templates."git-kirksw".content = ''
      [user]
        name = ${config.sops.placeholder."git/kirksw/name"}
        email = ${config.sops.placeholder."git/kirksw/email"}
        signingKey = ${config.sops.secrets."ssh/kirksw/private".path}
      [gpg]
        format = ssh
      [commit]
        gpgsign = true
      [url "ssh://git@github.com-kirksw/kirksw/"]
        insteadOf = https://github.com/kirksw/
        insteadOf = git@github.com:kirksw/
    '';
  };

  xdg.configFile = {
    "nix-agents/pi/bases/personal/profiles/personal-fallback/settings.json".text = piSettings;
    "nix-agents/pi/bases/personal/profiles/personal-fallback/models.json".text =
      baseSettings.targets.pi.personal."models.json";
    "nix-agents/pi/bases/personal/profiles/personal-fallback/AGENTS.md".source = "${assets}/AGENTS.md";
    "nix-agents/pi/bases/personal/profiles/personal-fallback/skills".source = "${assets}/skills";
    "nix-agents/pi/bases/personal/profiles/personal-fallback/extensions".source =
      "${assets}/extensions";
    "nix-agents/pi/bases/personal/profiles/personal-fallback/prompts".source = "${assets}/prompts";
  };
}
