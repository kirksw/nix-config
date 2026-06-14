{ inputs, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  mcpServers.lunar-skills = {
    type = "local";
    command = [ "${inputs.self.packages.${system}.lunar-skills-mcp}/bin/lunar-skills-mcp" ];
  };
}
