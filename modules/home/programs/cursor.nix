{
  self,
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  cursorMcpConfig = {
    mcpServers = {
      linear = {
        url = "https://mcp.linear.app/mcp";
      };
    };
  };
in
{
  options = {
    homeModules.cursor.enable = lib.mkEnableOption "enables cursor editor";
  };

  config = lib.mkIf config.homeModules.cursor.enable {
    home.file.".cursor/mcp.json".text = builtins.toJSON cursorMcpConfig;
  };
}
