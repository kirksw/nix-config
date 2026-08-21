{
  description = "Starter Configuration for MacOS and NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable.follows = "nixpkgs";

    darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    homebrew-brew = {
      url = "github:Homebrew/brew/5.1.9";
      flake = false;
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "homebrew-brew";
    };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0";
    flake-utils.url = "github:numtide/flake-utils";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lunar-tools = {
      url = "git+ssh://git@github.com/lunarway/lw-nix?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lunarctl.inputs.lunarctl.url =
        "git+ssh://git@github.com/lunarway/lunarctl?rev=149c51bec4176d1705bf6d38a40c56222ef84d2a";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-agents.url = "github:kirksw/nix-agents/main";
    swe-pruner-mcp.url = "github:kirksw/swe-pruner-mcp";
    deploy-rs.url = "github:serokell/deploy-rs";

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-openclaw.url = "github:openclaw/nix-openclaw";

    backend-engineering-practices = {
      url = "github:lunarway/backend-engineering-practices/master";
      flake = false;
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    last30days-skill = {
      url = "github:mvanhorn/last30days-skill";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    minimax-cli-skill = {
      url = "github:MiniMax-AI/cli?rev=3615170a2e26ec6003c4550cd1324b55ec8ad677";
      flake = false;
    };

    lavish-axi = {
      url = "github:kunchenguid/lavish-axi?rev=50b0facb61b5fc36cb1737e33b20d2894a64323b";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-schemas,
      flake-utils,
      deploy-rs,
      lunar-tools,
      nix-agents,
      git-hooks,
      neovim-nightly-overlay,
      nix-openclaw,
      ...
    }:
    let
      requireHostFields =
        name: required: cfg:
        let
          missing = builtins.filter (field: !(builtins.hasAttr field cfg)) required;
        in
        assert
          (missing == [ ])
          || throw "Host '${name}' is missing required fields: ${builtins.concatStringsSep ", " missing}";
        cfg;

      validateHostPaths =
        name: cfg:
        let
          _hostModule =
            assert
              builtins.pathExists cfg.hostModule
              || throw "Host '${name}' points to missing hostModule: ${toString cfg.hostModule}";
            cfg.hostModule;
          _homeModule =
            if cfg ? homeModule && cfg.homeModule != null then
              assert
                builtins.pathExists cfg.homeModule
                || throw "Host '${name}' points to missing homeModule: ${toString cfg.homeModule}";
              cfg.homeModule
            else
              null;
        in
        cfg;

      normalizeHost =
        name: cfg:
        let
          withRequired = requireHostFields name [ "system" "user" "hostModule" ] cfg;
          validated = validateHostPaths name withRequired;
        in
        validated
        // {
          overlays = validated.overlays or [ ];
        };

      mylibs = import ./lib {
        inherit (nixpkgs) lib;
        inherit inputs self;
      };

      defaultOverlays = import ./flake/overlays.nix { };

      darwinSystems =
        let
          raw = import ./flake/hosts/darwin {
            inherit
              lunar-tools
              nix-agents
              neovim-nightly-overlay
              ;
          };
        in
        builtins.mapAttrs (
          name: cfg:
          let
            host = normalizeHost name cfg;
          in
          host // { overlays = defaultOverlays ++ host.overlays; }
        ) raw;

      nixosSystems =
        let
          raw = import ./flake/hosts/nixos;
        in
        builtins.mapAttrs (
          name: cfg:
          let
            host = normalizeHost name cfg;
          in
          host // { overlays = defaultOverlays ++ host.overlays; }
        ) raw;

      mkPackageData = import ./flake/packages.nix {
        inherit
          nixpkgs
          inputs
          ;
      };
      mkApps = import ./flake/apps.nix {
        inherit
          nixpkgs
          mylibs
          inputs
          self
          ;
      };
      appCommandsBySystem = {
        aarch64-darwin = [
          "build"
          "switch"
          "rollback"
        ];
        x86_64-linux = [
          "build"
          "switch"
        ];
      };

      deploy = import ./flake/deploy.nix {
        inherit self deploy-rs;
      };

      deployChecks = import ./flake/checks.nix {
        inherit deploy-rs deploy;
      };

      exportedSchemas = import ./flake/schemas.nix;
    in
    let
      systemOutputs = flake-utils.lib.eachDefaultSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          packageData = mkPackageData system;
          appSet = mkApps {
            inherit system;
            appCommands = appCommandsBySystem.${system} or [ ];
            inherit (packageData) packageNames packages;
          };
          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nix-flake-check = {
                enable = true;
                entry = "${pkgs.writeShellScript "nix-flake-check" ''
                  export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1
                  exec ${pkgs.nix}/bin/nix flake check --no-build --impure
                ''}";
                files = "\\.nix$";
                pass_filenames = false;
              };
            };
          };
        in
        {
          packages = packageData.packages;

          apps = appSet;

          checks = {
            inherit pre-commit-check;
            wezterm-config-syntax =
              pkgs.runCommand "wezterm-config-syntax"
                {
                  nativeBuildInputs = [ pkgs.lua ];
                }
                ''
                  ${pkgs.lua}/bin/luac -p ${./config/wezterm/wezterm.lua}
                  touch $out
                '';

            sync-agents-settings-merge = pkgs.runCommand "sync-agents-settings-merge" { } ''
              export HOME="$TMPDIR/home"
              export XDG_CONFIG_HOME="$TMPDIR/config"

              settings_dir="$XDG_CONFIG_HOME/nix-agents/pi/bases/work/settings"
              profile_dir="$XDG_CONFIG_HOME/nix-agents/pi/bases/work/profiles/work-default"
              mkdir -p "$settings_dir" "$profile_dir"

              cat > "$settings_dir/mcporter.json" <<'JSON'
              {
                "mcpServers": {
                  "google-drive": { "command": "stale" },
                  "linear": { "url": "stale" }
                },
                "runtimeUserSetting": { "preserved": true }
              }
              JSON
              printf '{"servers":{"google-drive":{"tools":[]}}}\n' > "$profile_dir/mcp-cache.json"

              ${appSet.sync-agents.program}

              ${pkgs.jq}/bin/jq -e '.runtimeUserSetting.preserved == true' "$settings_dir/mcporter.json" >/dev/null
              ${pkgs.jq}/bin/jq -e '.mcpServers | has("google-drive") | not' "$settings_dir/mcporter.json" >/dev/null
              ${pkgs.jq}/bin/jq -e '.mcpServers.linear.url == "https://mcp.linear.app/mcp"' "$settings_dir/mcporter.json" >/dev/null
              test ! -e "$profile_dir/mcp-cache.json"
              touch $out
            '';

            herdr-cli-compatibility =
              pkgs.runCommand "herdr-cli-compatibility"
                {
                  nativeBuildInputs = [ self.packages.${system}.herdr ];
                }
                ''
                  GREP=${pkgs.gnugrep}/bin/grep \
                    ${pkgs.bash}/bin/bash ${./scripts/check-herdr-cli.sh} \
                    ${self.packages.${system}.herdr}/bin/herdr
                  touch $out
                '';

            mlx-dspark-server-smoke =
              if system == "aarch64-darwin" then
                pkgs.runCommand "mlx-dspark-server-smoke" { } ''
                  export HOME="$TMPDIR/home"
                  export CURL_BIN=${pkgs.curl}/bin/curl
                  export JQ_BIN=${pkgs.jq}/bin/jq
                  mkdir -p "$HOME"
                  ${pkgs.bash}/bin/bash ${./scripts/check-mlx-dspark.sh} \
                    ${self.packages.${system}.mlx-dspark}/bin/mlx-dspark
                  touch $out
                ''
              else
                pkgs.runCommand "mlx-dspark-server-smoke-skipped" { } "touch $out";

            pi-mlx-dspark-provider = pkgs.runCommand "pi-mlx-dspark-provider" { } ''
              export HOME="$TMPDIR/home"
              export XDG_CONFIG_HOME="$TMPDIR/config"
              ${appSet.sync-agents.program}

              profile_dir="$XDG_CONFIG_HOME/nix-agents/pi/bases/personal/profiles/personal-default"
              test -L "$profile_dir/models.json"
              ${pkgs.jq}/bin/jq -e \
                '.providers["mlx-dspark"] as $provider
                 | $provider.baseUrl == "http://127.0.0.1:18080"
                   and $provider.api == "anthropic-messages"
                   and $provider.models[0].id == "Qwen3-8B-4bit"
                   and $provider.models[0].contextWindow == 131072
                   and $provider.models[0].maxTokens == 8192' \
                "$profile_dir/models.json" >/dev/null
              ${pkgs.jq}/bin/jq -e '.defaultProvider == "zai"' "$profile_dir/settings.json" >/dev/null
              ${pkgs.jq}/bin/jq -e \
                '.providers | has("mlx-dspark") | not' \
                "$XDG_CONFIG_HOME/nix-agents/pi/bases/work/profiles/work-default/models.json" >/dev/null
              model_check_dir="$TMPDIR/pi-model-check"
              mkdir -p "$model_check_dir"
              cp "$profile_dir/models.json" "$model_check_dir/models.json"
              printf '{}\n' > "$model_check_dir/settings.json"
              PI_CODING_AGENT_DIR="$model_check_dir" \
                ${self.packages.${system}.pi}/bin/pi --no-extensions --list-models mlx-dspark \
                | ${pkgs.gnugrep}/bin/grep -F 'Qwen3-8B-4bit' >/dev/null
              touch $out
            '';

            pi-herdr-extension-load = pkgs.runCommand "pi-herdr-extension-load" { } ''
              export HOME="$TMPDIR/home"
              export PI_CODING_AGENT_DIR="$TMPDIR/pi-agent"
              export PI_OFFLINE=1
              mkdir -p "$HOME" "$PI_CODING_AGENT_DIR"

              printf '%s\n' '{"type":"get_state"}' \
                | ${self.packages.${system}.pi}/bin/pi \
                  --mode rpc \
                  --no-session \
                  --no-extensions \
                  --extension ${./agents/packages/pi-herdr/index.ts} \
                  > "$TMPDIR/response.jsonl"
              ${pkgs.jq}/bin/jq -s -e \
                'any(.[]; .type == "response" and .command == "get_state" and .success == true)' \
                "$TMPDIR/response.jsonl" >/dev/null
              touch $out
            '';

            agentic-factory-profiles =
              let
                localAgents = import ./agents { inherit pkgs; };
                agentInputs = inputs // {
                  inherit self;
                };
                agentsSrc = pkgs.runCommandLocal "nix-config-agents-src" { } ''
                  mkdir -p "$out"
                  cp -r ${./agents}/. "$out/"
                  chmod -R u+w "$out"
                '';
                profileMeta = nix-agents.lib.${system}.mkProfileMeta {
                  inherit pkgs;
                  target = "pi";
                  inputs = agentInputs;
                  modules = localAgents.piFactoryModules;
                  src = agentsSrc;
                };
                agentBaseSettings = import ./agents/base-settings.nix {
                  inherit self system;
                  lib = nixpkgs.lib;
                };
                expectedHomePackages = builtins.toJSON [
                  "local:pi-anthropic-communication-policy"
                  "local:pi-herdr"
                  "local:pi-mlflow-tracer"
                  "npm:@tintinweb/pi-subagents@0.14.3"
                  "npm:pi-permission-system@0.8.0"
                  "npm:pi-verbosity-control@0.3.0"
                  "npm:pi-web-access@0.13.0"
                ];
                expectedWorkPackages = builtins.toJSON (
                  (builtins.fromJSON expectedHomePackages) ++ [ "local:pi-agent-journal" ]
                );
                expectedHomePackagesFile = pkgs.writeText "home-factory-pi-packages.json" expectedHomePackages;
                expectedWorkPackagesFile = pkgs.writeText "work-factory-pi-packages.json" expectedWorkPackages;
                homeSettingsFile =
                  pkgs.writeText "home-factory-settings.json"
                    agentBaseSettings.targets.pi."home-factory"."settings.json";
                workSettingsFile =
                  pkgs.writeText "work-factory-settings.json"
                    agentBaseSettings.targets.pi."work-factory"."settings.json";
              in
              pkgs.runCommand "agentic-factory-profiles"
                {
                  nativeBuildInputs = [ pkgs.python3 ];
                }
                ''
                  [ "${profileMeta."home-factory".base}" = "home-factory" ]
                  [ "${profileMeta."work-factory".base}" = "work-factory" ]
                  [ -z "$(find ${profileMeta."home-factory".storePath}/agents ${
                    profileMeta."home-factory".storePath
                  }/skills -type f -print -quit)" ]
                  [ -z "$(find ${profileMeta."work-factory".storePath}/agents ${
                    profileMeta."work-factory".storePath
                  }/skills -type f -print -quit)" ]
                  [ -f "${profileMeta."home-factory".storePath}/extensions/minimal-mode/index.ts" ]
                  [ -f "${profileMeta."work-factory".storePath}/extensions/minimal-mode/index.ts" ]
                  python3 - "${expectedHomePackagesFile}" "${homeSettingsFile}" "${expectedWorkPackagesFile}" "${workSettingsFile}" <<'PY'
                  import json, sys
                  def normalize_package(package):
                      if package.endswith("/agents/packages/pi-anthropic-communication-policy"):
                          return "local:pi-anthropic-communication-policy"
                      if package.endswith("/agents/packages/pi-herdr"):
                          return "local:pi-herdr"
                      if package.endswith("/agents/packages/pi-agent-journal"):
                          return "local:pi-agent-journal"
                      if "-pi-mlflow-tracer-" in package:
                          return "local:pi-mlflow-tracer"
                      return package

                  for expected_path, settings_path in zip(sys.argv[1::2], sys.argv[2::2], strict=True):
                      expected = json.load(open(expected_path))
                      settings = json.load(open(settings_path))
                      packages = [normalize_package(package) for package in settings["packages"]]
                      assert packages == expected, (settings_path, settings["packages"])
                  PY
                  touch $out
                '';
          };

          devShells.default = pkgs.mkShell {
            inherit (pre-commit-check) shellHook;
          };
        }
      );
    in
    systemOutputs
    // {
      darwinConfigurations = builtins.mapAttrs mylibs.darwin.mkDarwinSystem darwinSystems;
    }
    // {
      nixosConfigurations = builtins.mapAttrs mylibs.nixos.mkNixosSystem nixosSystems;
    }
    // {
      inherit deploy exportedSchemas;
      schemas = flake-schemas.exportedSchemas // exportedSchemas;
      checks = nixpkgs.lib.recursiveUpdate (systemOutputs.checks or { }) deployChecks;
    };
}
