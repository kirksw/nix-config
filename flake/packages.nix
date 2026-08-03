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
    if name == "lunar-skills-mcp" then
      { backendEngineeringPractices = inputs.backend-engineering-practices; }
    else if name == "swe-pruner-mcp" then
      { inherit inputs; }
    else
      { };

  packages =
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = pkgs.callPackage (packagesDir + "/${name}") (packageArgs name);
      }) packageNames
    )
    // {
      google-drive-mcp-auth = pkgs.callPackage ../agents/packages/google-drive-mcp-auth { };
    };
in
{
  inherit packageNames packages;
}
