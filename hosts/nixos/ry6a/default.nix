# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  self,
  lib,
  config,
  pkgs,
  ...
}:

let
  tailscaleCertHost = "nixos-ry6a.tail54de03.ts.net";
  dashboardCertDir = "/var/lib/tailscale/certs/kubernetes-dashboard";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../../modules/shared
    ../../../modules/nixos
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-ry6a";
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Copenhagen";

  # Select internationalisation properties.
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

  # Configure console keymap
  console.keyMap = "uk";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    k8s = {
      isNormalUser = true;
      description = "k8s";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      # packages = with pkgs; [ ];
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

  # Nix settings
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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim
    fastfetch
    htop
    kubectl
  ];

  # List services that you want to enable:

  # Enable vvirtualisation
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [
    "root"
    "k8s"
  ];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Use classic dbus instead of dbus-broker to avoid user-session reload
  # failures during remote activation (deploy-rs over SSH).
  services.dbus.implementation = "dbus";

  # Open ports in the firewall.
  networking.firewall.enable = true;
  #networking.firewall.allowedTCPPorts = [ 6443 ];
  #networking.firewall.allowedUDPPorts = [ 8472 ];
  #networking.firewall.allowedTCPPortRanges = [
  #  {
  #    from = 30000;
  #    to = 32767;
  #  }
  #];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # we use tailscale for managing ssh access
  services.tailscale.enable = true;
  systemd.services.tailscaled.restartIfChanged = false;
  networking.nameservers = [
    "100.100.100.100"
    "8.8.8.8"
    "1.1.1.1"
  ];
  networking.search = [ "tail54de03.ts.net" ];

  # secrets
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
        sopsFile = "${self}/secrets/ssh/ry6a-root.yaml";
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

  # custom modules
  nixosModules.k3s = {
    enable = true;
    role = "server";
    nodeName = "nixos-ry6a";
    clusterInit = true;
    tokenFile = config.sops.secrets."k8s/node/secret".path;
  };

  # Keep MLflow private: the ClusterIP service is forwarded only on loopback,
  # then Tailscale Serve terminates Tailnet TLS on this node's MagicDNS name.
  systemd.services.mlflow-port-forward = {
    description = "Forward the MLflow ClusterIP service to localhost";
    after = [ "k3s.service" ];
    requires = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.k3s}/bin/k3s kubectl -n mlflow port-forward --address 127.0.0.1 service/mlflow 5000:5000";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  systemd.services.mlflow-tailscale-serve = {
    description = "Expose MLflow privately through Tailscale Serve";
    after = [
      "network-online.target"
      "tailscaled.service"
      "mlflow-port-forward.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "tailscaled.service"
      "mlflow-port-forward.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://127.0.0.1:5000";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https=443 off";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  systemd.services.kubernetes-dashboard-tailscale-cert = {
    description = "Issue Tailscale cert and sync dashboard TLS secret";
    after = [
      "network-online.target"
      "tailscaled.service"
      "k3s.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "k3s.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    script = ''
      set -euo pipefail
      install -d -m 0700 "${dashboardCertDir}"
      ${pkgs.tailscale}/bin/tailscale cert --cert-file "${dashboardCertDir}/tls.crt" --key-file "${dashboardCertDir}/tls.key" "${tailscaleCertHost}"
      for ns in kubernetes-dashboard uptime-kuma; do
        if ${pkgs.k3s}/bin/k3s kubectl get namespace "$ns" >/dev/null 2>&1; then
          ${pkgs.k3s}/bin/k3s kubectl -n "$ns" create secret tls kubernetes-dashboard-tls --cert="${dashboardCertDir}/tls.crt" --key="${dashboardCertDir}/tls.key" --dry-run=client -o yaml | ${pkgs.k3s}/bin/k3s kubectl apply -f -
        fi
      done
    '';
  };

  systemd.timers.kubernetes-dashboard-tailscale-cert = {
    description = "Rotate Tailscale dashboard TLS cert";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "12h";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };

}
