{
  self,
  lib,
  config,
  pkgs,
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
    k8s = {
      isNormalUser = true;
      description = "k8s";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };
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
      "k8s"
      "kisw"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    neovim
    fastfetch
    htop
    kubectl
  ];

  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [
    "root"
    "k8s"
  ];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  services.openssh.enable = true;
  networking.firewall.enable = true;

  system.stateVersion = "25.05";

  services.tailscale.enable = true;
  systemd.services.tailscaled.restartIfChanged = false;
  networking.nameservers = [
    "100.100.100.100"
    "8.8.8.8"
    "1.1.1.1"
  ];
  networking.search = [ "tail54de03.ts.net" ];

  sops = {
    defaultSopsFormat = "yaml";
    age.keyFile = "/root/.config/sops/age/keys.txt";

    secrets = {
      "k8s/node/secret" = {
        sopsFile = "${self}/secrets/k8s/node.yaml";
        key = "secret";
        mode = "0400";
      };

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
      install -m 0600 -o root -g root ${config.sops.secrets."ssh/root/authorizedKey".path} /etc/ssh/authorized_keys.d/root
    '';
  };

  nixosModules.k3s = {
    enable = true;
    role = "agent";
    nodeName = "nixos-ry4a";
    serverAddr = "https://192.168.10.66:6443";
    tokenFile = config.sops.secrets."k8s/node/secret".path;
  };
}
