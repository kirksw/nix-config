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

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
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
    nix-agents.url = "github:kirksw/nix-agents";
    swe-pruner-mcp.url = "github:kirksw/swe-pruner-mcp";
    deploy-rs.url = "github:serokell/deploy-rs";
    yazi.url = "github:sxyazi/yazi";

    backend-engineering-practices = {
      url = "github:lunarway/backend-engineering-practices/master";
      flake = false;
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
      yazi,
      git-hooks,
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
              yazi
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
        inherit nixpkgs mylibs inputs;
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

      checks = import ./flake/checks.nix {
        inherit deploy-rs deploy;
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
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
        };

        devShells.default = (import nixpkgs { inherit system; }).mkShell {
          inherit (pre-commit-check) shellHook;
        };
      }
    )
    // {
      darwinConfigurations = builtins.mapAttrs mylibs.darwin.mkDarwinSystem darwinSystems;
    }
    // {
      nixosConfigurations = builtins.mapAttrs mylibs.nixos.mkNixosSystem nixosSystems;
    }
    // {
      inherit deploy checks;
    };
}
