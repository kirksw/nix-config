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
      value = pkgs.callPackage (packagesDir + "/${name}") {
        inherit inputs;
      };
    }) packageNames
  );
in
{
  inherit packageNames packages;
}
