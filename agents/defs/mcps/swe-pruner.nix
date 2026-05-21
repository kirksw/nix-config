{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  mcpServers.swe-pruner = {
    type = "local";
    command = [ "${inputs.self.packages.${system}.swe-pruner-mcp}/bin/swe-pruner-mcp" ];
  };
}
