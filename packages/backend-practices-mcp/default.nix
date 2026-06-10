{
  lib,
  python3,
  writeShellApplication,
  backendEngineeringPractices,
}:

writeShellApplication {
  name = "backend-practices-mcp";
  runtimeInputs = [ python3 ];
  text = ''
    exec ${python3}/bin/python ${./server.py} --skills-root ${backendEngineeringPractices}/skills "$@"
  '';

  meta = {
    description = "MCP server for on-demand backend-engineering-practices skills";
    mainProgram = "backend-practices-mcp";
    platforms = lib.platforms.all;
  };
}
