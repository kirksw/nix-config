{
  lib,
}:

let
  registry = import ./registry.nix;

  enabledPackages = lib.filterAttrs (_name: package: package.enabled or false) registry;

  packageRef =
    name: package:
    let
      npmName = package.npmName or name;
      version = package.version;
    in
    "npm:${npmName}@${version}";

  packageRefs = lib.mapAttrsToList packageRef enabledPackages;
in
{
  inherit registry enabledPackages packageRefs;
}
