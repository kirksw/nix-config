{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  mcpServers.agent-observe = {
    type = "local";
    package = inputs.self.packages.${system}.agent-observe;
    args = [ "mcp" ];
  };
}
