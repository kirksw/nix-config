{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixosModules.kataK3s;
  template = pkgs.writeText "k3s-config-v3.toml.tmpl" ''
    {{ template "base" . }}

    [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.'kata']
      runtime_type = "io.containerd.kata.v2"
      runtime_path = "${pkgs.kata-runtime}/bin/containerd-shim-kata-v2"
      privileged_without_host_devices = true
  '';
in
{
  options.nixosModules.kataK3s.enable = lib.mkEnableOption "Kata Containers as an opt-in k3s runtime";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.k3s.enable && config.services.k3s.role == "server";
        message = "nixosModules.kataK3s requires a k3s server for RuntimeClass deployment.";
      }
    ];

    environment.systemPackages = [ pkgs.kata-runtime ];
    systemd = {
      services.k3s = {
        path = [ pkgs.kata-runtime ];
        serviceConfig.DeviceAllow = [
          "/dev/kvm rwm"
          "/dev/kmsg r"
          "/dev/vhost-vsock rwm"
          "/dev/vhost-net rwm"
          "/dev/net/tun rwm"
        ];
      };
      tmpfiles.settings."09-k3s-kata"."/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.tmpl"."L+".argument =
        "${template}";
    };

    services.k3s.manifests.kata-runtime-class.content = {
      apiVersion = "node.k8s.io/v1";
      kind = "RuntimeClass";
      metadata.name = "kata";
      handler = "kata";
      scheduling.nodeSelector."kubernetes.io/hostname" = config.networking.hostName;
    };
  };
}
