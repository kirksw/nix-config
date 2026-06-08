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

  # libvirtd in NixOS 26.11 uses LoadCredentialEncrypted which requires
  # systemd credential encryption setup. Override to use plain LoadCredential.
  systemd.services.libvirtd.serviceConfig = {
    LoadCredentialEncrypted = lib.mkForce "";
    LoadCredential = "secrets-encryption-key:/var/lib/libvirt/secrets/secrets-encryption-key";
  };
  system.activationScripts.libvirtSecretKey = {
    text = ''
      if [ ! -f /var/lib/libvirt/secrets/secrets-encryption-key ]; then
        install -d -m 0700 /var/lib/libvirt/secrets
        head -c 32 /dev/urandom | base64 > /var/lib/libvirt/secrets/secrets-encryption-key
        chmod 600 /var/lib/libvirt/secrets/secrets-encryption-key
      fi
    '';
  };

  # microvm.nix declarative microvms
  microvm.autostart = [ ];

  microvm.vms.test-vm = {
    autostart = false;
    config = {
      networking.hostName = "test-vm";
      networking.interfaces.eth0.ipv4.addresses = [{
        address = "10.0.0.2";
        prefixLength = 24;
      }];
      networking.defaultGateway = {
        address = "10.0.0.1";
        interface = "eth0";
      };
      services.openssh.enable = true;
      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6CnYKakaB/Uv7hgYngA69iP0HUy5DhZmNBaxsslbyW89xlJVLbtzlkGgxsfKQn/KHVxkn5TUYe7sfXNO/beGbX+ejlN3OWANT/cbkNOScLyn/kIUT0LKm6JxXXJUOK2g0jfMQNSd4b4b/OloXORCIJFst5pRrFTWbCkXYwNbsa698UCRlFWTDWPiiwjxedTu11PUFYnTQuC6DuXUZ3ZVXYR5lGhDwOq4ayLkAX9xZGSTDYDUh1hUoVxz+8u543QgsLeT1F4VYh54gwVIuluEyWO0olYnjHeqvGsJ77a7HcYjDeFwlMjUVB7GdkJ6+sOtdK/IDihtGd9Yqk6E42t/pQpOrsdkQqq8n/UhKd9E8LYt6xDqBPd1rgdyeZU2Y7RZ2UHlffbg6rpObHNo5tzTtbGQMfJ9s79o/C5xxYLi0S2CGiepd0h/OY+PoqcSlqMfG2mNzNGfMxpIKo/svFj4tuKIX3Pup4Zrtb4FXjgQneE7JO02MUjfsD1Zh5j3EhG8= kisw@Kirk-Sweeney.local"
      ];
      system.stateVersion = "25.05";
      microvm = {
        mem = 512;
        vcpu = 1;
        interfaces = [{
          type = "tap";
          id = "vm-test";
          mac = "02:00:00:00:00:01";
        }];
      };
    };
  };
}
