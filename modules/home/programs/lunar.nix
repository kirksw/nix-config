{
  pkgs,
  lib,
  config,
  ...
}:

let
  kubesealPublicCert = "${config.xdg.configHome}/lunar/kubeseal/public.pem";
  cmuxCli = pkgs.writeShellScriptBin "cmux" ''
    exec "${pkgs.cmux}/Applications/cmux.app/Contents/Resources/bin/cmux" "$@"
  '';
in
{
  options = {
    homeModules.lunar.enable = lib.mkEnableOption "enables lunar tooling";
  };

  config = lib.mkIf config.homeModules.lunar.enable {
    home.packages = with pkgs; [
      # general tooling
      kubeseal
      awscli2

      # internal tooling
      shuttle
      hamctl
      hubble
      dagger
      gitnow
      lunarctl
      cursor-cli
      amp-cli
      cmux
      (lib.hiPrio cmuxCli)
    ];

    home.sessionVariables = {
      GOPRIVATE = "go.lunarway.com,github.com/lunarway";
      LW_KUBESEAL_PUBLIC_CERT = kubesealPublicCert;
      CMUX_BUNDLED_CLI_PATH = "${pkgs.cmux}/Applications/cmux.app/Contents/Resources/bin/cmux";
    };
  };
}
