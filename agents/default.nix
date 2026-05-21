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

  sessionModules =
    if pkgs == null then
      [ ]
    else
      [
        (import ./defs/hooks/session-write.nix { inherit pkgs; })
      ];
in
{
  inherit defaultModules tieredModules sessionModules;

  defaultModulesWithSessions = defaultModules ++ sessionModules;
  tieredModulesWithSessions = tieredModules ++ sessionModules;
}
