{
  self,
  inputs,
  config,
  pkgs,
  lib,
  ...
}:

let
  rootSshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6CnYKakaB/Uv7hgYngA69iP0HUy5DhZmNBaxsslbyW89xlJVLbtzlkGgxsfKQn/KHVxkn5TUYe7sfXNO/beGbX+ejlN3OWANT/cbkNOScLyn/kIUT0LKm6JxXXJUOK2g0jfMQNSd4b4b/OloXORCIJFst5pRrFTWbCkXYwNbsa698UCRlFWTDWPiiwjxedTu11PUFYnTQuC6DuXUZ3ZVXYR5lGhDwOq4ayLkAX9xZGSTDYDUh1hUoVxz+8u543QgsLeT1F4VYh54gwVIuluEyWO0olYnjHeqvGsJ77a7HcYjDeFwlMjUVB7GdkJ6+sOtdK/IDihtGd9Yqk6E42t/pQpOrsdkQqq8n/UhKd9E8LYt6xDqBPd1rgdyeZU2Y7RZ2UHlffbg6rpObHNo5tzTtbGQMfJ9s79o/C5xxYLi0S2CGiepd0h/OY+PoqcSlqMfG2mNzNGfMxpIKo/svFj4tuKIX3Pup4Zrtb4FXjgQneE7JO02MUjfsD1Zh5j3EhG8= kisw@Kirk-Sweeney.local";
  routerHttpPort = 80;
  routerServicePort = 20128;
  routerPackage = self.packages.${pkgs.system}."9router";
  omniRoutePackage = self.packages.${pkgs.system}.omniroute;
  tailscaleAuthKeyFile = config.sops.secrets."tailscale/microvms/authKey".path;
  tailscaleAuthKeyDir = builtins.dirOf tailscaleAuthKeyFile;
  routerRuntimePackages = [
    pkgs.inetutils
    pkgs.nodejs
    pkgs.procps
    pkgs.which
  ];

  omniRoutePreStart = pkgs.writeShellScript "omniroute-pre-start" ''
    set -eu

    ${pkgs.coreutils}/bin/install -d -o router -g router -m 0700 /var/lib/omniroute /var/lib/omniroute/log_archives
    if [ ! -e /var/lib/omniroute/log_archives/legacy-request-logs.json ]; then
      # ponytail: upstream zips live logs during startup; marker skips that broken legacy migration.
      ${pkgs.coreutils}/bin/printf '%s\n' '{"migratedAt":"nix-preseed","archiveFilename":null}' > /var/lib/omniroute/log_archives/legacy-request-logs.json
    fi
    if [ ! -e /var/lib/omniroute/storage.sqlite ]; then
      # ponytail: fresh test VM, stale probe-failed DBs only make OmniRoute restore a broken DB forever.
      ${pkgs.coreutils}/bin/rm -f /var/lib/omniroute/storage.sqlite.probe-failed-*
    fi
    ${pkgs.coreutils}/bin/chown -R router:router /var/lib/omniroute
  '';

  openclawAcpxOverlay = final: prev: {
    openclawRuntimePlugins = prev.openclawRuntimePlugins // {
      acpx = prev.openclawRuntimePlugins.acpx.overrideAttrs (_: {
        # ponytail: upstream installer's fs.cpSync trips over the Nix store; plain cp works.
        installPhase = ''
          runHook preInstall

          mkdir -p "$out"
          cp -r ./. "$out/"
          rm -rf "$out/node_modules/.bin"

          if [ -n "''${OPENCLAW_GATEWAY_PACKAGE:-}" ] && [ -e "$OPENCLAW_GATEWAY_PACKAGE/lib/openclaw/package.json" ]; then
            mkdir -p "$out/node_modules"
            ln -sfn "$OPENCLAW_GATEWAY_PACKAGE/lib/openclaw" "$out/node_modules/openclaw"
          fi

          runHook postInstall
        '';
      });
    };

    openclaw-runtime-plugin-acpx = final.openclawRuntimePlugins.acpx;
  };

  assistants = [
    {
      name = "personal-assistant";
      kbRepo = "https://github.com/kirksw/kb-personal";
      authSecret = "tailscale/microvms/authKey";
      authKey = "assistantAuthKey";
      mac = "02:00:00:10:00:01";
    }
    {
      name = "household-assistant";
      kbRepo = "https://github.com/kirksw/kb-household";
      authSecret = "tailscale/microvms/authKey";
      authKey = "assistantAuthKey";
      mac = "02:00:00:10:00:02";
      openclaw = {
        router = "home-llm-router";
        secretsFile = "household";
        telegramAllowFrom = [
          8504646361
          8771595122
        ];
        modelFallbacks = [ "router-anthropic/glm/glm-5.2" ];
        sopsSecrets = [
          "telegram_bot_token"
          "llm_router_api_key"
          "gateway_token"
        ];
      };
    }
    {
      name = "sanja-assistant";
      kbRepo = "https://github.com/kirksw/kb-personal";
      authSecret = "tailscale/microvms/authKey";
      authKey = "assistantAuthKey";
      mac = "02:00:00:10:00:04";
      openclaw = {
        router = "home-llm-router";
        secretsFile = "sanja";
        telegramAllowFrom = [ 8771595122 ];
        modelFallbacks = [
          "router-openai/cx/gpt-5.4"
          "router-anthropic/glm/glm-5.2"
        ];
        sopsSecrets = [
          "telegram_bot_token"
          "llm_router_api_key"
          "gateway_token"
        ];
      };
    }
    {
      name = "kirk-assistant";
      kbRepo = "https://github.com/kirksw/kb-personal";
      authSecret = "tailscale/microvms/authKey";
      authKey = "assistantAuthKey";
      mac = "02:00:00:10:00:05";
      openclaw = {
        router = "home-llm-router";
        secretsFile = "kirk";
        telegramAllowFrom = [ 8504646361 ];
        sopsSecrets = [
          "telegram_bot_token"
          "llm_router_api_key"
          "gateway_token"
        ];
      };
    }
    {
      name = "work-assistant";
      kbRepo = "https://github.com/kirksw/kb-lunar";
      authSecret = "tailscale/microvms/authKey";
      authKey = "assistantAuthKey";
      mac = "02:00:00:10:00:03";
    }
  ];

  llmRouters = [
    {
      name = "home-llm-router";
      hostPort = 20129;
      sshPort = 20229;
      mac = "02:00:00:10:00:11";
    }
    {
      name = "work-llm-router";
      hostPort = 20130;
      sshPort = 20230;
      mac = "02:00:00:10:00:12";
    }
  ];

  testRouter = {
    name = "test-llm-router";
    hostPort = 20131;
    sshPort = 20231;
    mac = "02:00:00:10:00:13";
  };

  mkSopsSecret = assistant: {
    name = assistant.authSecret;
    value = {
      sopsFile = "${self}/secrets/tailscale/agent-microvms.yaml";
      key = assistant.authKey;
      mode = "0400";
    };
  };

  # Sops secrets for OpenClaw-enabled assistants.
  # Each key from <name>.yaml becomes a file under /run/secrets/assistants/<name>/.
  # Group-readable so the VM's agent user (in keys group) can read via virtiofs.
  mkOpenClawSopsSecrets =
    assistant:
    let
      sf = assistant.openclaw.secretsFile;
    in
    builtins.listToAttrs (
      map (key: {
        name = "assistants/${sf}/${key}";
        value = {
          sopsFile = "${self}/secrets/assistants/${sf}.yaml";
          inherit key;
          mode = "0440";
          group = "keys";
        };
      }) assistant.openclaw.sopsSecrets
    );

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
          bootstrap = "Install sandboxed OpenClaw and provision GitHub/LLM credentials manually after first boot. Persistent state lives in /var/lib/openclaw and /srv/assistant.";
        }
      );
    in
    {
      name = assistant.name;
      value = {
        autostart = true;
        # ponytail: avoid deploy-rs rollback on transient parallel MicroVM boot failures; restart target VMs manually when needed.
        restartIfChanged = false;

        # Extra modules for OpenClaw-enabled assistants
        extraModules =
          if assistant ? openclaw then
            [
              inputs.nix-openclaw.nixosModules.openclaw-gateway
              ./openclaw-assistant.nix
              ({ ... }: {
                assistant.openclaw.router = assistant.openclaw.router;
                # sopsDir is the virtiofs mount point where the VM reads shared secrets
                assistant.openclaw.sopsDir = "/run/host-secrets/openclaw";
                assistant.openclaw.telegramAllowFrom = assistant.openclaw.telegramAllowFrom or [ ];
                assistant.openclaw.modelFallbacks =
                  assistant.openclaw.modelFallbacks or [
                    "router-openai/cx/gpt-5.4"
                    "router-anthropic/glm/glm-5.2"
                  ];
                nixpkgs.overlays = [
                  inputs.nix-openclaw.overlays.default
                  openclawAcpxOverlay
                ];
              })
            ]
          else
            [ ];
        config = {
          networking.hostName = assistant.name;
          system.stateVersion = "25.05";

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          environment.variables = {
            OPENCLAW_HOME = "/var/lib/openclaw";
            ASSISTANT_KB_REPO_FILE = "/etc/assistant/kb-repo";
            ASSISTANT_WORKSPACE = "/srv/assistant/workspace";
          };

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
              home = "/srv/assistant/home";
              createHome = true;
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
            "d /srv/assistant/home 0700 agent users -"
            "d /srv/assistant/workspace 0755 agent users -"
            "d /srv/assistant/kb 0755 agent users -"
            "d /var/lib/openclaw 0700 agent users -"
            "d /var/lib/openclaw/config 0700 agent users -"
            "d /var/lib/openclaw/state 0700 agent users -"
          ];

          microvm = {
            hypervisor = "qemu";
            # OpenClaw + Docker sandbox needs more RAM
            mem = if assistant ? openclaw then 6144 else 4096;
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
              {
                image = "/var/lib/microvms/${assistant.name}/tailscale.img";
                mountPoint = "/var/lib/tailscale";
                size = 1024;
                fsType = "ext4";
                autoCreate = true;
              }
              {
                image = "/var/lib/microvms/${assistant.name}/openclaw.img";
                mountPoint = "/var/lib/openclaw";
                size = 8192;
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
            ]
            ++ (lib.optional (assistant ? openclaw) {
              source =
                builtins.dirOf
                  config.sops.secrets."assistants/${assistant.openclaw.secretsFile}/telegram_bot_token".path;
              mountPoint = "/run/host-secrets/openclaw";
              tag = "openclaw-secrets";
              proto = "virtiofs";
              readOnly = true;
            });
          };
        };
      };
    };

  mkRouterVm = router: {
    name = router.name;
    value = {
      autostart = true;
      # ponytail: avoid deploy-rs rollback on transient parallel MicroVM boot failures; restart target VMs manually when needed.
      restartIfChanged = false;
      config = {
        networking.hostName = router.name;
        system.stateVersion = "25.05";

        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        environment.systemPackages = [
          routerPackage
          pkgs.curl
          pkgs.htop
          pkgs.jq
        ]
        ++ routerRuntimePackages;

        users.groups.router = { };
        users.users = {
          root.openssh.authorizedKeys.keys = [ rootSshKey ];
          router = {
            isSystemUser = true;
            group = "router";
            home = "/var/lib/9router";
            createHome = false;
          };
        };

        services.openssh = {
          enable = true;
          hostKeys = [
            {
              path = "/var/lib/9router/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
            {
              path = "/var/lib/9router/ssh/ssh_host_rsa_key";
              type = "rsa";
              bits = 4096;
            }
          ];
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "prohibit-password";
          };
        };

        services.tailscale.enable = true;
        systemd.services.tailscaled.restartIfChanged = false;

        networking.firewall = {
          enable = true;
          allowedTCPPorts = [
            routerHttpPort
            22
          ];
        };
        networking.nameservers = [
          "100.100.100.100"
          "8.8.8.8"
          "1.1.1.1"
        ];
        networking.search = [ "tail54de03.ts.net" ];
        systemd.network.enable = true;

        systemd.tmpfiles.rules = [
          "d /var/lib/9router 0700 router router -"
          "d /var/lib/9router/ssh 0700 root root -"
        ];

        services.nginx = {
          enable = true;
          recommendedProxySettings = true;
          virtualHosts."_".locations."/".proxyPass = "http://127.0.0.1:${toString routerServicePort}";
        };

        systemd.services."9router" = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          path = routerRuntimePackages;
          environment = {
            DATA_DIR = "/var/lib/9router";
            HOME = "/var/lib/9router";
          };
          serviceConfig = {
            # ponytail: mounted MicroVM volume can come up root-owned; chown once before 9router writes its DB.
            ExecStartPre = "+${pkgs.coreutils}/bin/chown -R router:router /var/lib/9router";
            ExecStart = "${routerPackage}/bin/9router --port ${toString routerServicePort} --host 127.0.0.1 --no-browser --skip-update --log";
            Restart = "always";
            RestartSec = "5s";
            User = "router";
            Group = "router";
            WorkingDirectory = "/var/lib/9router";
          };
        };

        microvm = {
          hypervisor = "qemu";
          mem = 4096;
          vcpu = 2;
          interfaces = [
            {
              type = "user";
              id = "qemu";
              mac = router.mac;
            }
          ];
          forwardPorts = [
            {
              from = "host";
              proto = "tcp";
              host.port = router.hostPort;
              guest.port = routerHttpPort;
            }
            {
              from = "host";
              proto = "tcp";
              host.port = router.sshPort;
              guest.port = 22;
            }
          ];
          volumes = [
            {
              image = "/var/lib/microvms/${router.name}/9router.img";
              mountPoint = "/var/lib/9router";
              size = 8192;
              fsType = "ext4";
              autoCreate = true;
            }
            {
              image = "/var/lib/microvms/${router.name}/tailscale.img";
              mountPoint = "/var/lib/tailscale";
              size = 1024;
              fsType = "ext4";
              autoCreate = true;
            }
          ];
        };
      };
    };
  };

  mkOmniRouterVm = router: {
    name = router.name;
    value = {
      autostart = true;
      # ponytail: avoid deploy-rs rollback on transient parallel MicroVM boot failures; restart target VMs manually when needed.
      restartIfChanged = false;
      config = {
        networking.hostName = router.name;
        system.stateVersion = "25.05";

        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        environment.systemPackages = [
          omniRoutePackage
          pkgs.curl
          pkgs.htop
          pkgs.jq
        ]
        ++ routerRuntimePackages;

        users.groups.router = { };
        users.users = {
          root.openssh.authorizedKeys.keys = [ rootSshKey ];
          router = {
            isSystemUser = true;
            group = "router";
            home = "/var/lib/omniroute";
            createHome = false;
          };
        };

        services.openssh = {
          enable = true;
          hostKeys = [
            {
              path = "/var/lib/omniroute/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
            {
              path = "/var/lib/omniroute/ssh/ssh_host_rsa_key";
              type = "rsa";
              bits = 4096;
            }
          ];
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

        networking.firewall = {
          enable = true;
          allowedTCPPorts = [
            routerHttpPort
            22
          ];
        };
        networking.nameservers = [
          "100.100.100.100"
          "8.8.8.8"
          "1.1.1.1"
        ];
        networking.search = [ "tail54de03.ts.net" ];
        systemd.network.enable = true;

        systemd.tmpfiles.rules = [
          "d /var/lib/omniroute 0700 router router -"
          "d /var/lib/omniroute/ssh 0700 root root -"
        ];

        services.nginx = {
          enable = true;
          recommendedProxySettings = true;
          virtualHosts."_".locations."/".proxyPass = "http://127.0.0.1:${toString routerServicePort}";
        };

        systemd.services.omniroute = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          path = routerRuntimePackages;
          environment = {
            DATA_DIR = "/var/lib/omniroute";
            HOME = "/var/lib/omniroute";
            PORT = toString routerServicePort;
            OMNIROUTE_NO_UPDATE_NOTIFIER = "1";
            OMNIROUTE_SKIP_DB_HEALTHCHECK = "1";
          };
          serviceConfig = {
            ExecStartPre = "+${omniRoutePreStart}";
            ExecStart = "${omniRoutePackage}/bin/omniroute";
            Restart = "always";
            RestartSec = "5s";
            User = "router";
            Group = "router";
            # ponytail: omniroute's packaged server expects process cwd to be the app root.
            WorkingDirectory = "${omniRoutePackage}/lib/node_modules/omniroute";
          };
        };

        microvm = {
          hypervisor = "qemu";
          mem = 4096;
          vcpu = 2;
          interfaces = [
            {
              type = "user";
              id = "qemu";
              mac = router.mac;
            }
          ];
          forwardPorts = [
            {
              from = "host";
              proto = "tcp";
              host.port = router.hostPort;
              guest.port = routerHttpPort;
            }
            {
              from = "host";
              proto = "tcp";
              host.port = router.sshPort;
              guest.port = 22;
            }
          ];
          volumes = [
            {
              image = "/var/lib/microvms/${router.name}/omniroute.img";
              mountPoint = "/var/lib/omniroute";
              size = 8192;
              fsType = "ext4";
              autoCreate = true;
            }
            {
              image = "/var/lib/microvms/${router.name}/tailscale.img";
              mountPoint = "/var/lib/tailscale";
              size = 1024;
              fsType = "ext4";
              autoCreate = true;
            }
          ];
          shares = [
            {
              source = tailscaleAuthKeyDir;
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
  sops.secrets =
    # Deduplicate tailscale auth keys (all assistants share one key)
    builtins.listToAttrs (lib.unique (map (a: mkSopsSecret a) assistants))
    // builtins.foldl' (
      acc: a: if a ? openclaw then acc // mkOpenClawSopsSecrets a else acc
    ) { } assistants;

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = builtins.concatMap (router: [
    router.hostPort
    router.sshPort
  ]) (llmRouters ++ [ testRouter ]);

  systemd.tmpfiles.rules =
    (map (assistant: "d /var/lib/microvms/${assistant.name} 0700 root root -") assistants)
    ++ (map (router: "d /var/lib/microvms/${router.name} 0700 root root -") (
      llmRouters ++ [ testRouter ]
    ));

  microvm.vms =
    builtins.listToAttrs (map mkVm assistants)
    // builtins.listToAttrs (map mkRouterVm llmRouters)
    // builtins.listToAttrs [ (mkOmniRouterVm testRouter) ];
}
