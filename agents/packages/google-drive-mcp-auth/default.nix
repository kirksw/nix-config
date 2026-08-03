{
  lib,
  python3,
  writeShellApplication,
}:

writeShellApplication {
  name = "google-drive-mcp-auth";
  runtimeInputs = [ python3 ];
  text = ''
    exec ${python3}/bin/python ${./google-drive-mcp-auth.py} "$@"
  '';

  meta = {
    description = "Authenticated stdio MCP bridge for Google Drive MCP";
    mainProgram = "google-drive-mcp-auth";
    platforms = lib.platforms.all;
  };
}
