{
  self,
  pkgs,
  lib,
  config,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  cmuxPackage = self.packages.${system}.cmux;
  kubesealPublicCert = "${config.xdg.configHome}/lunar/kubeseal/public.pem";
  agentOpsJournalDir = "${config.xdg.dataHome}/nix-agents/journals";
  agentOpsJournalPath = "${agentOpsJournalDir}/agent-ops.txt";
  agentOpsJrnlConfigDir = "${config.xdg.configHome}/jrnl";
  agentOpsJrnlConfigPath = "${agentOpsJrnlConfigDir}/jrnl.yaml";
  yamlSingleQuote = value: "'${lib.replaceStrings [ "'" ] [ "''" ] value}'";
  agentOpsJrnlConfig = ''
    colors:
      body: none
      date: black
      tags: yellow
      title: cyan
    default_hour: 9
    default_minute: 0
    editor: nvim
    encrypt: false
    highlight: true
    indent_character: '|'
    journals:
      agent-ops:
        journal: ${yamlSingleQuote agentOpsJournalPath}
    linewrap: 79
    tagsymbols: '#@'
    template: false
    timeformat: '%F %r'
    version: v4.2
  '';
in
{
  options = {
    homeModules.lunar.enable = lib.mkEnableOption "enables lunar tooling";
  };

  config = lib.mkIf config.homeModules.lunar.enable {
    home.activation.agentOpsJournal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      journal_dir=${lib.escapeShellArg agentOpsJournalDir}
      journal_path=${lib.escapeShellArg agentOpsJournalPath}
      config_dir=${lib.escapeShellArg agentOpsJrnlConfigDir}
      config_path=${lib.escapeShellArg agentOpsJrnlConfigPath}

      mkdir -p "$journal_dir" "$config_dir"
      chmod 700 "$journal_dir" "$config_dir"
      if [ ! -e "$journal_path" ]; then
        umask 077
        : > "$journal_path"
      fi
      chmod 600 "$journal_path"

      # Home Manager's xdg.configFile would create a Nix-store symlink. jrnl
      # may rewrite its config, so bootstrap a mutable file only when absent.
      write_config=true
      if [ -L "$config_path" ]; then
        case "$(readlink "$config_path")" in
          /nix/store/*) rm -f "$config_path" ;;
          *) write_config=false ;; # Preserve a user-managed symlink.
        esac
      fi
      if [ "$write_config" = true ] && [ ! -e "$config_path" ]; then
        umask 077
        printf '%s\n' ${lib.escapeShellArg agentOpsJrnlConfig} > "$config_path"
      fi
      if [ "$write_config" = true ] && [ -f "$config_path" ]; then
        chmod 600 "$config_path"
      fi
    '';

    home.packages = with pkgs; [
      # general tooling
      kubeseal
      awscli2
      jrnl

      # internal tooling
      shuttle
      hamctl
      hubble
      dagger
      lunarctl
      cursor-cli
      amp-cli
      cmuxPackage
    ];

    home.sessionVariables = {
      GOPRIVATE = "go.lunarway.com,github.com/lunarway";
      LW_KUBESEAL_PUBLIC_CERT = kubesealPublicCert;
      CMUX_BUNDLED_CLI_PATH = "${cmuxPackage}/Applications/cmux.app/Contents/Resources/bin/cmux";
    };
  };
}
