{
  lib,
  python3,
  writeShellApplication,
  backendEngineeringPractices,
}:

writeShellApplication {
  name = "lunar-skills-mcp";
  runtimeInputs = [ python3 ];
  text = ''
    exec ${python3}/bin/python ${./server.py} --skills-root ${backendEngineeringPractices}/skills "$@"
  '';

  meta = {
    description = "MCP server for on-demand Lunar backend practice skills";
    mainProgram = "lunar-skills-mcp";
    platforms = lib.platforms.all;
  };
}
