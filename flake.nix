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
    ezgit = {
      url = "github:kirksw/ezgit/v0.0.19";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-land = {
      url = "github:kirksw/git-land/v0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      ezgit,
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
              ezgit
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
              profile_dir="$XDG_CONFIG_HOME/nix-agents/pi/bases/work/profiles/work-fallback"
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

            pi-experimental-profiles = pkgs.runCommand "pi-experimental-profiles" { } ''
              export HOME="$TMPDIR/home"
              export XDG_CONFIG_HOME="$TMPDIR/config"
              ${appSet.sync-agents.program}
              ${pkgs.python3}/bin/python3 ${./scripts/check-pi-experimental-profiles.py}
              mkdir -p "$XDG_CONFIG_HOME/nix-agents/pi/bases/personal/settings"
              printf '{}\n' > "$XDG_CONFIG_HOME/nix-agents/pi/bases/personal/settings/auth.json"
              ${appSet.sync-agents.program}
              ${pkgs.python3}/bin/python3 ${./scripts/check-pi-experimental-profiles.py}
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

              profile_dir="$XDG_CONFIG_HOME/nix-agents/pi/bases/personal-default/profiles/personal-default"
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
              for work_profile in work/profiles/work-fallback work-default/profiles/work-default work-browser/profiles/work-browser; do
                work_profile_dir="$XDG_CONFIG_HOME/nix-agents/pi/bases/$work_profile"
                ${pkgs.jq}/bin/jq -e \
                  '.providers["mlx-dspark"].models[0].id == "Qwen3-8B-4bit"
                   and .providers.openai.baseUrl == "https://eu.api.openai.com/v1"' \
                  "$work_profile_dir/models.json" >/dev/null
              done
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
