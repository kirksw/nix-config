{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.darwinModules.edgeDashboard;
  assets = ../../../config/edge-dashboard;
  observatoryApp = "${
    config.users.users.${config.system.primaryUser}.home
  }/Applications/EDGE Observatory.app";
in
{
  options.darwinModules.edgeDashboard = {
    enable = lib.mkEnableOption "EDGE dashboard lifecycle";
    mode = lib.mkOption {
      type = lib.types.enum [
        "legacy"
        "observatory"
      ];
      default = "legacy";
      description = "Dashboard implementation. Observatory is opt-in until physical acceptance tests pass.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.darwinModules.aerospace.enable;
        message = "The EDGE dashboard requires AeroSpace monitor assignments.";
      }
    ];
    launchd.user.agents.edge-dashboard.serviceConfig =
      if cfg.mode == "observatory" then
        {
          ProgramArguments = [
            "${observatoryApp}/Contents/MacOS/EDGE Observatory"
          ];
          EnvironmentVariables = {
            PATH = "/etc/profiles/per-user/${config.system.primaryUser}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
          };
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          ProcessType = "Interactive";
          LimitLoadToSessionType = "Aqua";
        }
      else
        {
          ProgramArguments = [
            "${pkgs.python3}/bin/python3"
            "${assets}/supervisor.py"
          ];
          EnvironmentVariables = {
            PATH =
              lib.makeBinPath [ pkgs.aerospace ]
              + ":/etc/profiles/per-user/${config.system.primaryUser}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
            PYTHONDONTWRITEBYTECODE = "1";
          };
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          ProcessType = "Interactive";
          LimitLoadToSessionType = "Aqua";
        };
  };
}
