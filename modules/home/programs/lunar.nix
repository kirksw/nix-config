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
      cmuxPackage
    ];

    home.sessionVariables = {
      GOPRIVATE = "go.lunarway.com,github.com/lunarway";
      LW_KUBESEAL_PUBLIC_CERT = kubesealPublicCert;
      CMUX_BUNDLED_CLI_PATH = "${cmuxPackage}/Applications/cmux.app/Contents/Resources/bin/cmux";
    };
  };
}
