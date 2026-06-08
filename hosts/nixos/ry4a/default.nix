{
  self,
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../../modules/shared
    ../../../modules/nixos
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-ry4a";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Copenhagen";
  i18n.defaultLocale = "en_DK.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8";
  };

  console.keyMap = "uk";

  users.users = {
    kisw = {
      isNormalUser = true;
      description = "my user";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "kisw"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    neovim
    fastfetch
    htop
    git
  ];

  services.openssh.enable = true;

  # Classic dbus to avoid user-session reload failures during remote activation
  services.dbus.implementation = "dbus";

  networking.firewall.enable = true;

  system.stateVersion = "25.05";

  # Tailscale for all remote access
  services.tailscale.enable = true;
  systemd.services.tailscaled.restartIfChanged = false;
  networking.nameservers = [
    "100.100.100.100"
    "8.8.8.8"
    "1.1.1.1"
  ];
  networking.search = [ "tail54de03.ts.net" ];

  # Secrets
  sops = {
    defaultSopsFormat = "yaml";
    age.keyFile = "/root/.config/sops/age/keys.txt";

    secrets = {
      "ssh/root/authorizedKey" = {
        sopsFile = "${self}/secrets/ssh/ry4a-root.yaml";
        key = "authorizedKey";
        mode = "0400";
      };
    };
  };

  system.activationScripts.rootAuthorizedKey = {
    deps = [ "setupSecrets" ];
    text = ''
      install -d -m 0755 /etc/ssh/authorized_keys.d
      install -m 0600 -o root -g root ${
        config.sops.secrets."ssh/root/authorizedKey".path
      } /etc/ssh/authorized_keys.d/root
    '';
  };

  # Microvm hypervisor host
  nixosModules.microvm-host = {
    enable = true;
    vmStoragePath = "/var/lib/microvms";
    defaultMemoryMB = 4096;
    defaultCores = 2;
  };

  # microvm.nix declarative microvms managed via config
  microvm.autostart = [ ];
}
