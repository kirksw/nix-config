{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.darwinModules.edgeDashboard;
  assets = ../../../config/edge-dashboard;
in
{
  options.darwinModules.edgeDashboard.enable = lib.mkEnableOption "single-service EDGE dashboard lifecycle";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.darwinModules.aerospace.enable;
        message = "The EDGE dashboard requires AeroSpace monitor assignments.";
      }
    ];
    launchd.user.agents.edge-dashboard.serviceConfig = {
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
