{
  lib,
  inputs,
  self,
}:

let
  inherit (inputs) darwin;
  homeManagerHelpers = import ./homemanager.nix {
    inherit
      lib
      inputs
      self
      ;
  };
  moduleArgs = config: builtins.removeAttrs config [ "system" ];

  mkDarwinSystem =
    hostname: config:
    darwin.lib.darwinSystem {
      specialArgs = {
        inherit inputs self;
      }
      // moduleArgs config;
      modules = [
        {
          documentation.doc.enable = false;
          documentation.man.enable = false;
          nixpkgs.hostPlatform = config.system;
          nixpkgs.overlays = (config.overlays or [ ]);
        }
        inputs.sops-nix.darwinModules.sops
        inputs.home-manager.darwinModules.home-manager
        inputs.determinate.darwinModules.default
        config.hostModule
        (homeManagerHelpers.mkHomeManagerModule config)
      ]
      ++ lib.optionals config.enableHomebrew [
        inputs.nix-homebrew.darwinModules.nix-homebrew
      ];
    };
in
{
  inherit mkDarwinSystem;
}
