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
    _: hostConfig:
    darwin.lib.darwinSystem {
      specialArgs = {
        inherit inputs self;
      }
      // moduleArgs hostConfig;
      modules = [
        (
          { config, ... }:
          {
            documentation.enable = false;
            system.tools.darwin-uninstaller.enable = false;
            nixpkgs.hostPlatform = hostConfig.system;
            nixpkgs.overlays = hostConfig.overlays or [ ];
            assertions = [
              {
                assertion =
                  !(
                    builtins.hasAttr hostConfig.user config.users.users
                    && config.users.users.${hostConfig.user}.createHome
                  )
                  || lib.elem hostConfig.user config.users.knownUsers;
                message = "New Home Manager user '${hostConfig.user}' must be listed in users.knownUsers";
              }
            ];
          }
        )
        inputs.sops-nix.darwinModules.sops
        inputs.home-manager.darwinModules.home-manager
        inputs.determinate.darwinModules.default
        hostConfig.hostModule
        (homeManagerHelpers.mkHomeManagerModule hostConfig)
      ]
      ++ lib.optionals hostConfig.enableHomebrew [
        inputs.nix-homebrew.darwinModules.nix-homebrew
      ];
    };
in
{
  inherit mkDarwinSystem;
}
