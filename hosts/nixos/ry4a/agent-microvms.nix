{
  self,
  config,
  pkgs,
  ...
}:

let
  rootSshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6CnYKakaB/Uv7hgYngA69iP0HUy5DhZmNBaxsslbyW89xlJVLbtzlkGgxsfKQn/KHVxkn5TUYe7sfXNO/beGbX+ejlN3OWANT/cbkNOScLyn/kIUT0LKm6JxXXJUOK2g0jfMQNSd4b4b/OloXORCIJFst5pRrFTWbCkXYwNbsa698UCRlFWTDWPiiwjxedTu11PUFYnTQuC6DuXUZ3ZVXYR5lGhDwOq4ayLkAX9xZGSTDYDUh1hUoVxz+8u543QgsLeT1F4VYh54gwVIuluEyWO0olYnjHeqvGsJ77a7HcYjDeFwlMjUVB7GdkJ6+sOtdK/IDihtGd9Yqk6E42t/pQpOrsdkQqq8n/UhKd9E8LYt6xDqBPd1rgdyeZU2Y7RZ2UHlffbg6rpObHNo5tzTtbGQMfJ9s79o/C5xxYLi0S2CGiepd0h/OY+PoqcSlqMfG2mNzNGfMxpIKo/svFj4tuKIX3Pup4Zrtb4FXjgQneE7JO02MUjfsD1Zh5j3EhG8= kisw@Kirk-Sweeney.local";

  assistants = [
    {
      name = "personal-assistant";
      kbRepo = "https://github.com/kirksw/kb-personal";
      authSecret = "tailscale/microvms/personal-assistant/authKey";
      authKey = "personalAssistantAuthKey";
      mac = "02:00:00:10:00:01";
    }
    {
      name = "household-assistant";
      kbRepo = "https://github.com/kirksw/kb-household";
      authSecret = "tailscale/microvms/household-assistant/authKey";
      authKey = "householdAssistantAuthKey";
      mac = "02:00:00:10:00:02";
    }
    {
      name = "work-assistant";
      kbRepo = "https://github.com/kirksw/kb-lunar";
      authSecret = "tailscale/microvms/work-assistant/authKey";
      authKey = "workAssistantAuthKey";
      mac = "02:00:00:10:00:03";
    }
  ];

  mkSopsSecret = assistant: {
    name = assistant.authSecret;
    value = {
      sopsFile = "${self}/secrets/tailscale/agent-microvms.yaml";
      key = assistant.authKey;
      mode = "0400";
    };
  };

  mkVm =
    assistant:
    let
      authKeyFile = config.sops.secrets.${assistant.authSecret}.path;
      authKeyDir = builtins.dirOf authKeyFile;
      kbRepoFile = pkgs.writeText "${assistant.name}-kb-repo" assistant.kbRepo;
      profileJson = pkgs.writeText "${assistant.name}-profile.json" (
        builtins.toJSON {
          inherit (assistant) name kbRepo;
          role = "persistent-openclaw-assistant";
          bootstrap = "Install sandboxed OpenClaw and provision GitHub/LLM credentials manually after first boot.";
        }
      );
    in
    {
      name = assistant.name;
      value = {
        autostart = true;
        config = {
          networking.hostName = assistant.name;
          system.stateVersion = "25.05";

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          environment.systemPackages = with pkgs; [
            curl
            fd
            git
            htop
            jq
            neovim
            nodejs
            openssh
            python3
            ripgrep
            tmux
          ];

          environment.etc = {
            "assistant/kb-repo".source = kbRepoFile;
            "assistant/profile.json".source = profileJson;
          };

          users.users = {
            root.openssh.authorizedKeys.keys = [ rootSshKey ];
            agent = {
              isNormalUser = true;
              description = "Persistent OpenClaw assistant operator";
              extraGroups = [ "wheel" ];
              openssh.authorizedKeys.keys = [ rootSshKey ];
            };
          };
          security.sudo.wheelNeedsPassword = false;

          services.openssh = {
            enable = true;
            settings = {
              PasswordAuthentication = false;
              PermitRootLogin = "prohibit-password";
            };
          };

          services.tailscale = {
            enable = true;
            authKeyFile = "/run/host-secrets/tailscale/authKey";
          };
          systemd.services.tailscaled.restartIfChanged = false;

          networking.firewall.enable = true;
          networking.nameservers = [
            "100.100.100.100"
            "8.8.8.8"
            "1.1.1.1"
          ];
          networking.search = [ "tail54de03.ts.net" ];
          systemd.network.enable = true;

          systemd.tmpfiles.rules = [
            "d /srv/assistant 0755 agent users -"
            "d /srv/assistant/workspace 0755 agent users -"
          ];

          microvm = {
            hypervisor = "qemu";
            mem = 4096;
            vcpu = 2;
            interfaces = [
              {
                type = "user";
                id = "qemu";
                mac = assistant.mac;
              }
            ];
            volumes = [
              {
                image = "/var/lib/microvms/${assistant.name}/assistant.img";
                mountPoint = "/srv/assistant";
                size = 20480;
                fsType = "ext4";
                autoCreate = true;
              }
            ];
            shares = [
              {
                source = authKeyDir;
                mountPoint = "/run/host-secrets/tailscale";
                tag = "tailscale-secrets";
                proto = "virtiofs";
                readOnly = true;
              }
            ];
          };
        };
      };
    };
in
{
  sops.secrets = builtins.listToAttrs (map mkSopsSecret assistants);

  systemd.tmpfiles.rules = map (
    assistant: "d /var/lib/microvms/${assistant.name} 0700 root root -"
  ) assistants;

  microvm.vms = builtins.listToAttrs (map mkVm assistants);
}
