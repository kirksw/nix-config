{ self, deploy-rs }:
let
  mkNode =
    {
      nodeName,
      configName,
      hostname,
    }:
    {
    inherit hostname;
    sshUser = "root";
    sshOpts = [
      "-o"
      "HostKeyAlias=${nodeName}"
    ];

    remoteBuild = true;
    fastConnection = true;

    profiles.system = {
      user = "root";
      path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.${configName};
      activationTimeout = 600;
    };
  };
in
{
  nodes = {
    # Preferred: direct LAN OpenSSH path.
    nixos-ry6a = mkNode {
      nodeName = "nixos-ry6a";
      configName = "nixos-ry6a";
      hostname = "192.168.10.66";
    };

    # Optional: Tailnet OpenSSH path (not Tailscale SSH).
    nixos-ry6a-ts = mkNode {
      nodeName = "nixos-ry6a";
      configName = "nixos-ry6a";
      hostname = "100.121.104.120";
    };

    nixos-ry6b = mkNode {
      nodeName = "nixos-ry6b";
      configName = "nixos-ry6b";
      hostname = "192.168.10.92";
    };

    nixos-ry4a = mkNode {
      nodeName = "nixos-ry4a";
      configName = "nixos-ry4a";
      hostname = "192.168.10.56";
    };

    nixos-ry4a-ts = mkNode {
      nodeName = "nixos-ry4a";
      configName = "nixos-ry4a";
      hostname = "100.66.204.106";
    };
  };
}
