{
  lib,
}:

let
  registry = import ./registry.nix;

  enabledPackages = lib.filterAttrs (_name: package: package.enabled or false) registry;

  packageRef =
    name: package:
    if package ? ref then
      package.ref
    else
      let
        npmName = package.npmName or name;
        version = package.version;
      in
      "npm:${npmName}@${version}";

  packageRefs = lib.mapAttrsToList packageRef enabledPackages;
  packageRefsFor = names: map (name: packageRef name registry.${name}) names;
in
{
  inherit
    registry
    enabledPackages
    packageRefs
    packageRefsFor
    ;
}
