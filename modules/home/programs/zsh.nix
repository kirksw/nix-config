{
  self,
  inputs,
  pkgs,
  lib,
  config,
  nixDirectory,
  ...
}:

let
  selectedPreset = builtins.fromTOML (
    builtins.readFile "${self}/config/zsh/starship/presets/pure.toml"
  );
in
{
  options = {
    homeModules.zsh.enable = lib.mkEnableOption "enables zsh";
  };

  config = lib.mkIf config.homeModules.zsh.enable {
    programs = {
      starship = {
        enable = true;
        enableZshIntegration = true;
        settings = selectedPreset;
      };

      fzf = {
        enable = true;
        enableZshIntegration = false; # defer
        tmux.enableShellIntegration = true;
      };

      zoxide = {
        enable = true;
        enableZshIntegration = false; # defer
      };

      direnv = {
        enable = true;
        enableZshIntegration = false; # defer
        nix-direnv.enable = true;
      };

      yazi = {
        enable = true;
        package = pkgs.yazi;
        enableZshIntegration = false; # defer
      };

      zsh = {
        enable = true;
        autocd = true;
        enableCompletion = true;

        # DISABLED - manually deferred below
        autosuggestion.enable = false;
        syntaxHighlighting.enable = false;

        defaultKeymap = "viins";
        completionInit = "autoload -Uz compinit && compinit -C -u";

        # NOTE: uncomment for debugging
        # zprof.enable = true;

        plugins = [ ];

        shellAliases = {
          la = "ls -la";
          ll = "ls -l";
          nu = "pushd ${nixDirectory} && nix flake update && popd";
          ns = "pushd ${nixDirectory} && sudo darwin-rebuild --flake .#aarch64-darwin && popd";

          gn = "gitnow";
          "docker-compose" = "docker compose";
          hubble = "aws_wrapper hubble";
          k9s = "k8s_wrapper k9s";
          kubectl = "k8s_wrapper kubectl";
        };

        history = {
          size = 10000;
          path = "${config.xdg.dataHome}/zsh/history";
        };

        # NOTE: 500: early init, 550: before comp, 1000: general, 1500: last
        initContent = lib.mkMerge [
          (lib.mkOrder 500 ''
            # Load nix (critical for PATH)
            if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
              . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
              . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
            fi

            # Inline brew PATH (faster than eval subshell)
            if [[ -d /opt/homebrew ]]; then
              export HOMEBREW_PREFIX="/opt/homebrew"
              export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
              export HOMEBREW_REPOSITORY="/opt/homebrew"
              export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
              export MANPATH="/opt/homebrew/share/man:$MANPATH"
              export INFOPATH="/opt/homebrew/share/info:$INFOPATH"
            fi

            export PATH="$HOME/.local/bin:$PATH"

            #if [[ $TERM != "dumb" ]]; then
            #  eval "${self}/config/zsh/starship_init.zsh"
            #fi
          '')

          (lib.mkOrder 1000 (''
            if (( $+commands[direnv] )); then
              eval "$(direnv hook zsh)"
            fi

            if (( $+commands[mise] )); then
              eval "$(mise activate zsh --shims)"
            fi

            # load zsh-defer first
            source "${pkgs.zsh-defer}/share/zsh-defer/zsh-defer.plugin.zsh"

            # Defer plugins
            zsh-defer eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
            zsh-defer source "${pkgs.fzf}/share/fzf/key-bindings.zsh"
            zsh-defer source "${pkgs.fzf}/share/fzf/completion.zsh"
            zsh-defer eval "$(${pkgs.yazi}/bin/yazi --init zsh 2>/dev/null || true)"
            zsh-defer source "${pkgs.lunar-zsh-plugin}/share/zsh/plugins/lunar-zsh-plugin/lunar.plugin.zsh"

            # load last
            source "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
            source "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
          ''))
        ];
      };
    };

    home = {
      packages = with pkgs; [
        jq
        yq
        gum
      ];

      file.".aws/config".source = "${pkgs.lunar-zsh-plugin}/.aws/config";
    };
  };
}
