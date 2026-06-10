{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  mcpServers.backend-practices = {
    type = "local";
    command = [ "${inputs.self.packages.${system}.backend-practices-mcp}/bin/backend-practices-mcp" ];
  };
}
