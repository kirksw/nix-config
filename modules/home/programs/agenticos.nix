{ config, lib, pkgs, ... }:

let
  agenticosCheckout =
    "${config.home.homeDirectory}/git/github.com/kirksw/agenticOS";

  piAgenticos = pkgs.writeShellScriptBin "pi-agenticos" ''
    set -euo pipefail

    export AGENTICOS_INSTANCE="lunarOS"

    exec pi \
      -e "${agenticosCheckout}/src/extension.mjs" \
      "$@"
  '';
in
{
  options.homeModules.agenticos.enable = lib.mkEnableOption
    "enables the agenticOS Pi extension with the LunarOS instance";

  config = lib.mkIf config.homeModules.agenticos.enable {
    home.packages = [ piAgenticos ];
    home.shellAliases.pi = "pi-agenticos";
  };
}
