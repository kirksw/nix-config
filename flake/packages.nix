{
  nixpkgs,
  inputs,
}:
system:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  packagesDir = ../packages;
  packageNames = builtins.filter (name: builtins.pathExists (packagesDir + "/${name}/default.nix")) (
    builtins.attrNames (builtins.readDir packagesDir)
  );
  packageArgs =
    name:
    if name == "backend-practices-mcp" then
      { backendEngineeringPractices = inputs.backend-engineering-practices; }
    else if name == "swe-pruner-mcp" then
      { inherit inputs; }
    else if name == "multica-selfhost" then
      { inherit (packages) multica; }
    else
      { };

  packages = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = pkgs.callPackage (packagesDir + "/${name}") (packageArgs name);
    }) packageNames
  );
in
{
  inherit packageNames packages;
}
