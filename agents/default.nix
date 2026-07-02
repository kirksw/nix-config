{
  pkgs ? null,
}:

let
  defaultModules = [
    ./presets/default.nix
    ./presets/profiles.nix
  ];

  tieredModules = [
    ./presets/tiered.nix
    ./presets/profiles.nix
  ];

  piTargetModules = [
    ./targets/pi/provider-overrides.nix
  ];

  piModules = defaultModules ++ piTargetModules;
  piFactoryModules = [ ./presets/factory.nix ];

  sessionModules =
    if pkgs == null then
      [ ]
    else
      [
        (import ./defs/hooks/session-write.nix { inherit pkgs; })
      ];
in
{
  inherit
    defaultModules
    tieredModules
    piTargetModules
    piModules
    piFactoryModules
    sessionModules
    ;

  defaultModulesWithSessions = defaultModules ++ sessionModules;
  tieredModulesWithSessions = tieredModules ++ sessionModules;
  piModulesWithSessions = piModules ++ sessionModules;
}
