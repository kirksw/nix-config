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
  routerRuntimePackages = [
    pkgs.inetutils
    pkgs.nodejs
    pkgs.procps
    pkgs.which
  ];
  # ponytail: upstream installer's fs.cpSync trips over the Nix store; plain cp works.
  openclawAcpxPlainCpInstall = peerLink: ''
    runHook preInstall

    mkdir -p "$out"
    cp -r ./. "$out/"
    rm -rf "$out/node_modules/.bin"

    ${
      if peerLink then
        ''
          if [ -n "''${OPENCLAW_GATEWAY_PACKAGE:-}" ] && [ -e "$OPENCLAW_GATEWAY_PACKAGE/lib/openclaw/package.json" ]; then
            mkdir -p "$out/node_modules"
            ln -sfn "$OPENCLAW_GATEWAY_PACKAGE/lib/openclaw" "$out/node_modules/openclaw"
          fi
        ''
      else
        ""
    }

    runHook postInstall
  '';
  openclawAcpxOverlay = final: prev: {
    openclawRuntimePlugins = prev.openclawRuntimePlugins // {
      acpx = prev.openclawRuntimePlugins.acpx.overrideAttrs (_: {
        installPhase = openclawAcpxPlainCpInstall true;
      });
    };

    openclaw-runtime-plugin-acpx = final.openclawRuntimePlugins.acpx;

    # The gateway bundles its own acpx copy through the same broken installer;
    # swap in a plain-cp build with the peer link dropped so it cannot depend
    # on the gateway itself, then forward the patched gateway into the bundle.
    openclaw-gateway = prev.openclaw-gateway.override {
      bundledAcpx = final.openclawRuntimePlugins.acpx.overrideAttrs (old: {
        installPhase = openclawAcpxPlainCpInstall false;
        env = builtins.removeAttrs (old.env or { }) [ "OPENCLAW_GATEWAY_PACKAGE" ];
      });
    };
    openclaw = prev.openclaw.override {
      openclaw-gateway = final.openclaw-gateway;
    };
  };

  assistants = [
    {
      name = "sanja-assistant";
      kbRepo = "https://github.com/kirksw/kb-personal";
      authSecret = "tailscale/microvms/authKey";
      authKey = "assistantAuthKey";
      mac = "02:00:00:10:00:04";
      memoryMB = 8192;
      openclaw = {
        router = "home-llm-router";
        providerMode = "litellm";
        modelPrimary = "litellm/openai/gpt-5.6-luna";
        modelFallbacks = [
          "litellm/minimax-m3"
          "litellm/glm-5.2"
        ];
        modelAllowlist = [
          "litellm/openai/gpt-5.6-luna"
          "litellm/minimax-m3"
          "litellm/glm-5.2"
        ];
        thinkingDefault = "medium";
        reasoningDefault = "on";
        secretsFile = "sanja";
        telegramAllowFrom = [ 8771595122 ];
        sopsSecrets = [
          "telegram_bot_token"
          "gateway_token"
          "litellm_api_key"
        ];
      };
    }
    {
      name = "kirk-assistant";
      kbRepo = "https://github.com/kirksw/kb-personal";
      authSecret = "tailscale/microvms/authKey";
      authKey = "assistantAuthKey";
      mac = "02:00:00:10:00:05";
      memoryMB = 8192;
      openclaw = {
        router = "home-llm-router";
        providerMode = "litellm";
        modelAllowlist = [
          "litellm/*"
        ];
        modelPrimary = "litellm/openai/gpt-5.6-luna";
        modelFallbacks = [
          "litellm/minimax-m3"
          "litellm/glm-5.2"
        ];
        thinkingDefault = "medium";
        reasoningDefault = "on";
        secretsFile = "kirk";
        telegramAllowFrom = [ 8504646361 ];
        sopsSecrets = [
          "telegram_bot_token"
          "gateway_token"
          "litellm_api_key"
        ];
      };
    }
  ];

  llmRouters = [ ];

  personalAgent = {
    name = "personal-agent";
    authSecret = "tailscale/microvms/authKey";
    authKey = "assistantAuthKey";
    mac = "02:00:00:10:00:06";
  };

  herdrPiIntegration = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/ogulcancelik/herdr/v0.8.2/src/integration/assets/pi/herdr-agent-state.ts";
    hash = "sha256-mxxBzXJSD8Kr5fKirsmVwSqSbM6ETfRyx/1fyuT02/o=";
  };
  localAgents = import ../../../agents { inherit pkgs; };
  localAgentsSrc = ../../../agents;
  agentBaseSettings = import ../../../agents/base-settings.nix {
    inherit self lib;
    system = pkgs.system;
  };
  personalPiPackageSettings = pkgs.writeText "personal-agent-pi-packages.json" (
    builtins.toJSON { packages = agentBaseSettings.piPersonalPackageRefs; }
  );
  nixAgentsLib = inputs.nix-agents.lib.${pkgs.system};
  agentInputs = inputs // {
    inherit self;
  };
  personalPiAgentSystem = nixAgentsLib.mkAgentSystem {
    inherit pkgs;
    target = "pi";
    inputs = agentInputs;
    modules = localAgents.piModules;
    src = localAgentsSrc;
  };
  personalPiBaseProfileMeta = nixAgentsLib.mkProfileMeta {
    inherit pkgs;
    target = "pi";
    inputs = agentInputs;
    modules = localAgents.piModules;
    src = localAgentsSrc;
  };
  personalPiProfile = personalPiBaseProfileMeta."personal-default";
  personalPiProfileMeta = personalPiBaseProfileMeta // {
    "personal-default" = personalPiProfile // {
      storePath = pkgs.runCommandLocal "nix-config-personal-agent-profile" { } ''
        cp -r ${personalPiProfile.storePath} "$out"
        chmod -R u+w "$out"
        mkdir -p "$out/extensions"
        cp ${herdrPiIntegration} "$out/extensions/herdr-agent-state.ts"
      '';
    };
  };
  personalPi = nixAgentsLib.mkWrappedTool (
    {
      inherit pkgs;
      target = "pi";
      tool = self.packages.${pkgs.system}.pi;
      agentSystem = personalPiAgentSystem;
      profileMeta = personalPiProfileMeta;
      profile = "personal-default";
    }
    // lib.optionalAttrs ((builtins.functionArgs nixAgentsLib.mkWrappedTool) ? syncMode) {
      syncMode = "bootstrap";
    }
  );

  mkSopsSecret = assistant: {
    name = assistant.authSecret;
    value = {
      sopsFile = "${self}/secrets/tailscale/agent-microvms.yaml";
      key = assistant.authKey;
      mode = "0400";
    };
  };

  directProviderSecretKeys = {
    minimax_api_key = {
      sopsFile = "${self}/secrets/api/default.yaml";
      key = "minimax";
    };
    zai_api_key = {
      sopsFile = "${self}/secrets/api/default.yaml";
      key = "zai";
    };
  };

  personalAgentProviderSecrets = builtins.listToAttrs (
    map
      (name: {
        name = "personal-agent/${name}";
        value = {
          inherit (directProviderSecretKeys.${name}) key;
          sopsFile = directProviderSecretKeys.${name}.sopsFile;
          mode = "0440";
          owner = "kisw";
          group = "kvm";
        };
      })
      [
        "minimax_api_key"
        "zai_api_key"
      ]
  );

  # Sops secrets for OpenClaw-enabled assistants.
  # Per-assistant keys come from secrets/assistants/<name>.yaml. Direct-provider
  # credentials are mounted only for assistants configured for direct access.
  # Group-readable so the VM's agent user (in keys group) can read via virtiofs.
  mkOpenClawSopsSecrets =
    assistant:
    let
      sf = assistant.openclaw.secretsFile;
      sopsKeys = builtins.listToAttrs (
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
      directSopsKeys =
        if assistant ? openclaw then
          if (assistant.openclaw.providerMode or "router") == "direct" then
            builtins.listToAttrs (
              map
                (name: {
                  value = {
                    inherit (directProviderSecretKeys.${name}) key;
                    sopsFile = directProviderSecretKeys.${name}.sopsFile;
                    mode = "0440";
                    group = "keys";
                  };
                  name = "assistants/${sf}/${name}";
                })
                [
                  "minimax_api_key"
                  "zai_api_key"
                ]
            )
          else
            { }
        else
          { };
    in
    sopsKeys // directSopsKeys;

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
        autostart = assistant.autostart or true;
        # ponytail: avoid deploy-rs rollback on transient parallel MicroVM boot failures; restart target VMs manually when needed.
        restartIfChanged = false;

        # Extra modules for OpenClaw-enabled assistants
        extraModules =
          if assistant ? openclaw then
            [
              inputs.nix-openclaw.nixosModules.openclaw-gateway
              ({ ... }: {
                _module.args.self = self;
              })
              ./openclaw-assistant.nix
              ({ ... }: {
                assistant.openclaw.router = assistant.openclaw.router;
                assistant.openclaw.providerMode = assistant.openclaw.providerMode or "router";
                assistant.openclaw.modelPrimary =
                  assistant.openclaw.modelPrimary or "router-anthropic/minimax/MiniMax-M3";
                assistant.openclaw.modelAllowlist = assistant.openclaw.modelAllowlist or [ ];
                assistant.openclaw.thinkingDefault = assistant.openclaw.thinkingDefault or "off";
                assistant.openclaw.reasoningDefault = assistant.openclaw.reasoningDefault or "off";
                assistant.openclaw.sherpaRuntimeDir = self.packages.${pkgs.system}."sherpa-onnx-runtime";
                assistant.openclaw.sherpaModelDir = self.packages.${pkgs.system}."sherpa-onnx-lessac-model";
                # sopsDir is the virtiofs mount point where the VM reads shared secrets
                assistant.openclaw.sopsDir = "/run/host-secrets/openclaw";
                assistant.openclaw.telegramAllowFrom = assistant.openclaw.telegramAllowFrom or [ ];
                assistant.openclaw.modelFallbacks =
                  assistant.openclaw.modelFallbacks or [ "router-anthropic/glm/glm-5.2" ];
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

          environment.systemPackages =
            with pkgs;
            [
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
            ]
            ++ lib.optionals (assistant ? openclaw) [
              self.packages.${pkgs.system}.gifgrep
              self.packages.${pkgs.system}."sherpa-onnx-runtime"
              self.packages.${pkgs.system}."sherpa-onnx-lessac-model"
              github-cli
              openai-whisper
              poppler-utils
              qpdf
              tesseract
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
            openFirewall = false;
            hostKeys = [
              {
                path = "/srv/assistant/ssh/ssh_host_ed25519_key";
                type = "ed25519";
              }
              {
                path = "/srv/assistant/ssh/ssh_host_rsa_key";
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
            extraSetFlags = [ "--ssh" ];
          };
          systemd.services.tailscaled.restartIfChanged = false;

          networking.firewall = {
            enable = true;
            interfaces.tailscale0.allowedTCPPorts = [ 22 ];
          };
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
            "d /srv/assistant/ssh 0700 root root -"
            "d /var/lib/openclaw 0700 agent users -"
            "d /var/lib/openclaw/config 0700 agent users -"
            "d /var/lib/openclaw/state 0700 agent users -"
          ];

          microvm = {
            hypervisor = "qemu";
            # OpenClaw + Docker sandbox needs more RAM
            mem = assistant.memoryMB or (if assistant ? openclaw then 6144 else 4096);
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

  personalAgentVm =
    let
      authKeyFile = config.sops.secrets.${personalAgent.authSecret}.path;
      authKeyDir = builtins.dirOf authKeyFile;
      providerKeyDir = builtins.dirOf config.sops.secrets."personal-agent/zai_api_key".path;
      piLauncher = pkgs.writeShellScriptBin "pi" ''
        zaiKeyFile=/run/personal-agent-secrets/zai_api_key
        minimaxKeyFile=/run/personal-agent-secrets/minimax_api_key

        if [ -r "$zaiKeyFile" ]; then
          export PERSONAL_ZAI_API_KEY="$(${pkgs.coreutils}/bin/cat "$zaiKeyFile")"
        fi
        if [ -r "$minimaxKeyFile" ]; then
          export PERSONAL_MINIMAX_API_KEY="$(${pkgs.coreutils}/bin/cat "$minimaxKeyFile")"
        fi

        export BLADE_CONSENT=reject
        export BLADE_NO_WARMING=1
        export BLADE_PROFILE_DIR=/home/agent/.blade/profile
        export CHROME_PATH=${pkgs.chromium}/bin/chromium
        export PATH=/home/agent/.config/nix-agents/pi/bases/personal/profiles/personal-default/npm/node_modules/.bin:$PATH

        exec ${personalPi}/bin/pi "$@"
      '';
    in
    {
      name = personalAgent.name;
      value = {
        autostart = true;
        restartIfChanged = false;
        config = {
          networking.hostName = personalAgent.name;
          system.stateVersion = "25.05";

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          programs.nix-ld = {
            enable = true;
            libraries = [ pkgs.stdenv.cc.cc.lib ];
          };

          environment.systemPackages = [
            piLauncher
            pkgs.agent-browser
            pkgs.chromium
            pkgs.curl
            pkgs.fd
            pkgs.git
            pkgs.herdr
            pkgs.htop
            pkgs.jq
            pkgs.neovim
            pkgs.nodejs
            pkgs.openssh
            pkgs.ripgrep
            pkgs.xvfb
          ];

          environment.variables = {
            AGENT_BROWSER_CONFIRM_ACTIONS = "fill,download,upload,state";
            AGENT_BROWSER_CONTENT_BOUNDARIES = "1";
            AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
            AGENT_BROWSER_MAX_OUTPUT = "50000";
            AGENT_BROWSER_PROFILE = "/home/agent/.agent-browser/profile";
            EDITOR = "nvim";
            PERSONAL_AGENT_WORKSPACE = "/srv/workspace";
          };

          users.users = {
            root.openssh.authorizedKeys.keys = [ rootSshKey ];
            agent = {
              isNormalUser = true;
              description = "Personal Pi agent operator";
              home = "/home/agent";
              createHome = true;
              extraGroups = [ "wheel" ];
              openssh.authorizedKeys.keys = [ rootSshKey ];
            };
          };
          security.sudo.wheelNeedsPassword = false;

          services.openssh = {
            enable = true;
            openFirewall = false;
            hostKeys = [
              {
                path = "/home/agent/.ssh/host/ssh_host_ed25519_key";
                type = "ed25519";
              }
              {
                path = "/home/agent/.ssh/host/ssh_host_rsa_key";
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
            extraSetFlags = [ "--ssh" ];
          };
          systemd.services.tailscaled.restartIfChanged = false;

          systemd.services.personal-agent-browser-skills = {
            description = "Reconcile personal-agent browser skills";
            wantedBy = [ "multi-user.target" ];
            before = [ "multi-user.target" ];
            unitConfig.RequiresMountsFor = [ "/home/agent" ];
            serviceConfig.Type = "oneshot";
            script = ''
              source=${personalPiProfileMeta."personal-default".storePath}/skills
              target=/home/agent/.config/nix-agents/pi/bases/personal/profiles/personal-default/skills

              ${pkgs.coreutils}/bin/install -d -m 0755 -o agent -g users "$target"
              ${pkgs.coreutils}/bin/rm -rf "$target/bladebro"
              for skill in \
                activities-search-bladebro \
                agent-browser \
                google-flights-bladebro \
                google-hotels \
                google-hotels-bladebro \
                travel-search-bladebro
              do
                ${pkgs.coreutils}/bin/rm -rf "$target/$skill"
                ${pkgs.coreutils}/bin/cp -R --no-preserve=mode,ownership "$source/$skill" "$target/$skill"
                ${pkgs.coreutils}/bin/chown -R agent:users "$target/$skill"
                ${pkgs.coreutils}/bin/chmod -R u=rwX,go=rX "$target/$skill"
              done
            '';
          };

          systemd.services.personal-agent-pi-packages = {
            description = "Reconcile personal-agent Pi packages";
            wantedBy = [ "multi-user.target" ];
            before = [ "multi-user.target" ];
            unitConfig.RequiresMountsFor = [ "/home/agent" ];
            serviceConfig.Type = "oneshot";
            script = ''
              target=/home/agent/.config/nix-agents/pi/bases/personal/state/settings.json
              source=${personalPiPackageSettings}
              tmp=$(${pkgs.coreutils}/bin/mktemp)
              trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT

              ${pkgs.coreutils}/bin/install -d -m 0755 -o agent -g users "$(${pkgs.coreutils}/bin/dirname "$target")"
              if [ -f "$target" ] && ${pkgs.jq}/bin/jq empty "$target" >/dev/null 2>&1; then
                ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$target" "$source" >"$tmp"
              else
                ${pkgs.coreutils}/bin/cp "$source" "$tmp"
              fi
              ${pkgs.coreutils}/bin/install -m 0600 -o agent -g users "$tmp" "$target"
            '';
          };

          systemd.services.personal-agent-provider-secrets = {
            description = "Stage personal-agent provider secrets";
            wantedBy = [ "multi-user.target" ];
            before = [ "multi-user.target" ];
            unitConfig.RequiresMountsFor = [ "/run/host-secrets/providers" ];
            serviceConfig.Type = "oneshot";
            script = ''
              ${pkgs.coreutils}/bin/install -d -m 0700 -o agent -g users /run/personal-agent-secrets
              ${pkgs.coreutils}/bin/install -m 0400 -o agent -g users /run/host-secrets/providers/zai_api_key /run/personal-agent-secrets/zai_api_key
              ${pkgs.coreutils}/bin/install -m 0400 -o agent -g users /run/host-secrets/providers/minimax_api_key /run/personal-agent-secrets/minimax_api_key
            '';
          };

          networking.firewall = {
            enable = true;
            interfaces.tailscale0.allowedTCPPorts = [ 22 ];
          };
          networking.nameservers = [
            "100.100.100.100"
            "8.8.8.8"
            "1.1.1.1"
          ];
          networking.search = [ "tail54de03.ts.net" ];
          systemd.network.enable = true;

          systemd.tmpfiles.rules = [
            "d /home/agent 0700 agent users -"
            "d /home/agent/.config 0700 agent users -"
            "d /home/agent/.agent-browser 0700 agent users -"
            "d /home/agent/.agent-browser/profile 0700 agent users -"
            "d /home/agent/.blade 0700 agent users -"
            "d /home/agent/.blade/profile 0700 agent users -"
            "d /home/agent/.config/herdr 0700 agent users -"
            "d /home/agent/.ssh 0700 agent users -"
            "d /home/agent/.ssh/host 0700 root root -"
            "d /srv/workspace 0755 agent users -"
            "C+ /home/agent/.config/herdr/config.toml 0600 agent users - /etc/personal-agent/herdr-config.toml"
          ];

          environment.etc."personal-agent/herdr-config.toml".text = ''
            [session]
            resume_agents_on_restore = true

            [ui.toast]
            delivery = "herdr"

            [ui]
            show_agent_labels_on_pane_borders = true
          '';

          microvm = {
            hypervisor = "qemu";
            mem = 8192;
            vcpu = 4;
            interfaces = [
              {
                type = "user";
                id = "qemu";
                mac = personalAgent.mac;
              }
            ];
            volumes = [
              {
                image = "/var/lib/microvms/${personalAgent.name}/home.img";
                mountPoint = "/home/agent";
                size = 32768;
                fsType = "ext4";
                autoCreate = true;
              }
              {
                image = "/var/lib/microvms/${personalAgent.name}/workspace.img";
                mountPoint = "/srv/workspace";
                size = 65536;
                fsType = "ext4";
                autoCreate = true;
              }
              {
                image = "/var/lib/microvms/${personalAgent.name}/tailscale.img";
                mountPoint = "/var/lib/tailscale";
                size = 1024;
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
              {
                source = providerKeyDir;
                mountPoint = "/run/host-secrets/providers";
                tag = "provider-secrets";
                proto = "9p";
                securityModel = "passthrough";
                readOnly = true;
              }
            ];
          };
        };
      };
    };

  mkRouterVm = router: {
    name = router.name;
    value = {
      autostart = false;
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

in
{
  sops.secrets =
    # Deduplicate tailscale auth keys (all assistants share one key)
    builtins.listToAttrs (lib.unique (map (a: mkSopsSecret a) (assistants ++ [ personalAgent ])))
    // personalAgentProviderSecrets
    // builtins.foldl' (
      acc: a: if a ? openclaw then acc // mkOpenClawSopsSecrets a else acc
    ) { } assistants;

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = builtins.concatMap (router: [
    router.hostPort
    router.sshPort
  ]) llmRouters;

  systemd.services."microvm@personal-agent".serviceConfig.ExecStartPre = [
    "+${pkgs.writeShellScript "personal-agent-secret-permissions" ''
      secretDir=$(${pkgs.coreutils}/bin/readlink -f /run/secrets/personal-agent)
      ${pkgs.coreutils}/bin/chgrp kvm "$secretDir"
      ${pkgs.coreutils}/bin/chmod 0750 "$secretDir"
    ''}"
  ];

  systemd.tmpfiles.rules =
    (map (assistant: "d /var/lib/microvms/${assistant.name} 0700 root root -") assistants)
    ++ [ "d /var/lib/microvms/${personalAgent.name} 0700 root root -" ]
    ++ (map (router: "d /var/lib/microvms/${router.name} 0700 root root -") (llmRouters));

  microvm.vms =
    builtins.listToAttrs (map mkVm assistants)
    // {
      ${personalAgentVm.name} = personalAgentVm.value;
    }
    // builtins.listToAttrs (map mkRouterVm llmRouters);
}
