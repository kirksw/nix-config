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
    users = {
      kirk = {
        home = "/Users/kirk";
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRojqfJdEXsAAXK4+5G6YLHQ5QpZOsiwwXAb5txy11Z kirk@cntd.io"
        ];
      };
      root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRojqfJdEXsAAXK4+5G6YLHQ5QpZOsiwwXAb5txy11Z kirk@cntd.io"
      ];
      agent = {
        uid = 502;
        home = "/Users/agent";
        shell = pkgs.zsh;
        description = "Unattended development agent";
        createHome = true;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRojqfJdEXsAAXK4+5G6YLHQ5QpZOsiwwXAb5txy11Z kirk@cntd.io"
        ];
      };
    };
  };

  environment = {
    systemPackages = [ pkgs.herdr ];
    shells = [ pkgs.zsh ];

    # Keep Nix available to deploy-rs in non-login root SSH commands only.
    etc."ssh/sshd_config.d/102-root-nix-path.conf".text = ''
      Match User root
        SetEnv PATH=/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
    '';
  };
  programs.zsh.enable = true;
  services.openssh.enable = true;
  system.activationScripts.postActivation.text = ''
    if ! /usr/sbin/dseditgroup -o checkmember -m agent com.apple.access_ssh >/dev/null 2>&1; then
      /usr/sbin/dseditgroup -o edit -a agent -t user com.apple.access_ssh
    fi
  '';

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
