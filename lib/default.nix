{
  self,
  lib,
  inputs,
}:

{
  homemanager = import ./homemanager.nix {
    inherit
      lib
      inputs
      self
      ;
  };
  darwin = import ./darwin.nix {
    inherit
      lib
      inputs
      self
      ;
  };
  nixos = import ./nixos.nix {
    inherit
      lib
      inputs
      self
      ;
  };
  app = import ./app.nix {
    inherit
      lib
      inputs
      ;
  };
  paths = import ./paths.nix { };
  mcp = import ./mcp.nix {
    inherit
      lib
      self
      ;
  };
}
