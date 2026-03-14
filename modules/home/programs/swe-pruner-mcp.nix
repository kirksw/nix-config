{
  self,
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  swePrunerMcp =
    self.packages.${system}.swe-pruner-mcp or inputs.swe-pruner-mcp.packages.${system}.default or null;
in
{
  options.homeModules.swePrunerMcp = {
    enable = lib.mkEnableOption "enables SWE-Pruner MCP server for context-aware code pruning";

    command = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if swePrunerMcp != null then "${swePrunerMcp}/bin/swe-pruner-mcp" else null;
      readOnly = true;
      description = "Command path for the upstream SWE-Pruner MCP package.";
    };
  };

  config = lib.mkIf config.homeModules.swePrunerMcp.enable {
    assertions = [
      {
        assertion = swePrunerMcp != null;
        message = "swe-pruner-mcp package is missing from flake outputs for this system.";
      }
    ];

    home.sessionVariables = {
      STATS_FILE = "${config.home.homeDirectory}/.cache/swe-pruner/stats.json";
      MODEL_PATH = "${config.home.homeDirectory}/.cache/swe-pruner/models/code-pruner";
    };

    home.activation.swePrunerMcpDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.home.homeDirectory}/.cache/swe-pruner/models"
      mkdir -p "${config.home.homeDirectory}/.cache/swe-pruner"
    '';

    home.packages = [ swePrunerMcp ];
  };
}
