{
  pkgs,
  ...
}:
{
  imports = [
    ../../../modules/shared
    ../../../modules/darwin/services/tailscale.nix
  ];

  darwinModules.tailscale.enable = true;

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

  determinateNix.enable = true;
  nixpkgs.config.allowUnfree = true;
  system = {
    stateVersion = 6;
    primaryUser = "kirk";
    checks.verifyNixPath = false;
  };
}
