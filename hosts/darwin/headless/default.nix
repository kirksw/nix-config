{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../../../modules/shared
    ../../../modules/darwin/services/tailscale.nix
  ];

  darwinModules.tailscale.enable = true;

  launchd.daemons.tailscale-ssh = {
    script = ''
      exec ${config.services.tailscale.package}/bin/tailscale set --ssh
    '';
    serviceConfig = {
      RunAtLoad = true;
      # Retry until tailscaled is ready to accept the setting.
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 10;
    };
  };

  networking = {
    hostName = "nix-mm1";
    computerName = "nix-mm1";
    localHostName = "nix-mm1";
  };

  users = {
    knownUsers = [ "agent" ];
    users.kirk = {
      home = "/Users/kirk";
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRojqfJdEXsAAXK4+5G6YLHQ5QpZOsiwwXAb5txy11Z kirk@cntd.io"
      ];
    };
    users.agent = {
      uid = 502;
      home = "/Users/agent";
      shell = pkgs.zsh;
      description = "Unattended development agent";
      createHome = true;
    };
  };

  environment.shells = [ pkgs.zsh ];
  programs.zsh.enable = true;
  services.openssh.enable = true;

  determinateNix = {
    enable = true;
    customSettings.trusted-users = [
      "root"
      "kirk"
    ];
  };
  nixpkgs.config.allowUnfree = true;
  system = {
    stateVersion = 6;
    primaryUser = "kirk";
    checks.verifyNixPath = false;
  };
}
