{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.nixosModules.microvm-host;
in
{
  options.nixosModules.microvm-host = {
    enable = lib.mkEnableOption "microvm hypervisor host with libvirt";

    vmStoragePath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/microvms";
      description = "Directory where microvm state and disk images are stored.";
    };

    defaultMemoryMB = lib.mkOption {
      type = lib.types.int;
      default = 4096;
      description = "Default memory allocation in MB for microvms.";
    };

    defaultCores = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Default number of vCPU cores per microvm.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Kernel support for KVM and networking
    boot.kernelModules = [
      "kvm-amd"
      "br_netfilter"
      "tun"
      "vhost_vsock"
    ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
    };

    # Libvirt for management and QEMU backend
    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;
    virtualisation.spiceUSBRedirection.enable = true;
    programs.virt-manager.enable = true;

    # Ensure the vm storage directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.vmStoragePath} 0755 root root -"
    ];

    environment.systemPackages = with pkgs; [
      qemu_kvm
      virt-manager
      bridge-utils
      curl
      jq
    ];

    users.groups.libvirtd.members = [
      "root"
      "kisw"
    ];

    # Allow incoming SSH on tailscale interface for remote VM management
    networking.firewall.enable = true;
  };
}
