{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  mcpServers.google-drive = {
    type = "local";
    command = [ "${inputs.self.packages.${system}.google-drive-mcp-auth}/bin/google-drive-mcp-auth" ];
  };
}
