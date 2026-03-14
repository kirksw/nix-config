{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.nixosModules.k3s;
in
{
  options.nixosModules.k3s = {
    enable = lib.mkEnableOption "enables k3s on this node";

    role = lib.mkOption {
      type = lib.types.enum [
        "server"
        "agent"
      ];
      default = "server";
      description = "k3s node role.";
    };

    clusterInit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Bootstrap the cluster. Use only on the first server.";
    };

    serverAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://u1:6443";
      description = "API server address to join (required for non-initial servers and agents).";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      example = "/var/lib/secrets/k3s-token";
      description = "Path to file containing the k3s token.";
    };

    # Optional: explicit node name
    nodeName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "nixos-ry6a";
      description = "Node name to report to the cluster (defaults to hostname if null).";
    };

    # Optional: disable built-in Traefik
    disableTraefik = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable bundled Traefik installation via --disable=traefik.";
    };

    # Optional: any extra flags to pass verbatim
    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--tls-san=10.0.0.10" ];
      description = "Additional flags appended to the k3s service invocation.";
    };
  };

  # Only apply when this module is enabled via nixosModules.k3s.enable
  config = lib.mkIf cfg.enable {
    # Kernel prerequisites for container networking
    # Set sysctls required by k3s/kubelet and CNIs
    boot.kernelModules = [ "br_netfilter" ];
    boot.kernel.sysctl = lib.mkMerge [
      (lib.mkDefault {
        "net.ipv4.ip_forward" = 1;
        "net.bridge.bridge-nf-call-iptables" = 1;
        "net.bridge.bridge-nf-call-ip6tables" = 1;
      })
      {
        "vm.overcommit_memory" = 1;
        "kernel.panic" = 10;
        "kernel.panic_on_oops" = 1;
      }
    ];

    # Firewall defaults depending on role
    networking.firewall = {
      allowedUDPPorts = [
        8472
      ];
      allowedTCPPorts = [
        6443
        2379
        2380
      ];
      allowedTCPPortRanges = [
        {
          from = 30000;
          to = 32767;
        } # NodePort range
      ];
    };

    # Build base flags set from options
    services.k3s = {
      enable = true;
      inherit (cfg) role clusterInit tokenFile;
      extraFlags =
        let
          base = [
            "--protect-kernel-defaults"
          ]
          ++ (lib.optional (cfg.role == "server") "--write-kubeconfig-mode=0644")
          ++ (lib.optional cfg.disableTraefik "--disable=traefik")
          ++ (lib.optional (cfg.nodeName != null) "--node-name=${cfg.nodeName}");
        in
        base ++ cfg.extraFlags;
    }
    // lib.optionalAttrs (cfg.serverAddr != null) { inherit (cfg) serverAddr; };

    # Optional: kubectl on the node
    environment.systemPackages = [ pkgs.kubectl ];
  };
}
