{
  lib,
  inputs,
  self,
}:

let
  inherit (inputs)
    nixpkgs
    sops-nix
    disko
    home-manager
    ;
  homeManagerHelpers = import ./homemanager.nix {
    inherit lib inputs self;
  };

  mkNixosSystem =
    hostname: config:
    nixpkgs.lib.nixosSystem {
      inherit (config) system;
      specialArgs = {
        inherit inputs self;
      }
      // config;
      modules = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        config.hostModule
        { nixpkgs.overlays = (config.overlays or [ ]); }
      ]
      ++ lib.optionals (config.enableHomeManager or false) [
        home-manager.nixosModules.home-manager
        (homeManagerHelpers.mkHomeManagerModule config)
      ];
    };
in
{
  inherit mkNixosSystem;
}
