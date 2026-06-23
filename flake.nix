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
    flake-utils.url = "github:numtide/flake-utils";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lunar-tools = {
      url = "git+ssh://git@github.com/lunarway/lw-nix?ref=feat/refactor";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";
    nix-agents.url = "github:kirksw/nix-agents/main";
    swe-pruner-mcp.url = "github:kirksw/swe-pruner-mcp";
    deploy-rs.url = "github:serokell/deploy-rs";

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      deploy-rs,
      lunar-tools,
      llm-agents,
      nix-agents,
      git-hooks,
      neovim-nightly-overlay,
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
              llm-agents
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
    in
    let
      systemOutputs = flake-utils.lib.eachDefaultSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          packageData = mkPackageData system;
          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nix-flake-check = {
                enable = true;
                entry = "nix flake check --no-build";
                files = "\\.nix$";
                pass_filenames = false;
              };
            };
          };
        in
        {
          packages = packageData.packages;

          apps = mkApps {
            inherit system;
            appCommands = appCommandsBySystem.${system} or [ ];
            inherit (packageData) packageNames packages;
          };

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
      inherit deploy;
      checks = nixpkgs.lib.recursiveUpdate (systemOutputs.checks or { }) deployChecks;
    };
}
