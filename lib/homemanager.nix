{
  lib,
  self,
  inputs,
}:

let
  paths = import ./paths.nix { };
  moduleArgs = config: builtins.removeAttrs config [ "system" ];
in
{
  mkHomeManagerModule =
    config:
    { ... }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        users.${config.user} = import config.homeModule;
        sharedModules = [
          inputs.sops-nix.homeManagerModules.sops
          ../modules/home
          {
            manual = {
              html.enable = false;
              json.enable = false;
              manpages.enable = false;
            };
          }
        ];
        extraSpecialArgs = {
          inherit
            inputs
            self
            paths
            ;
        }
        // moduleArgs config;
      };
    };
}
