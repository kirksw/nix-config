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

  packages = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = pkgs.callPackage (packagesDir + "/${name}") (
        if name == "swe-pruner-mcp" then { inherit inputs; } else { }
      );
    }) packageNames
  );
in
{
  inherit packageNames packages;
}
