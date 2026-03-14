{
  self,
  pkgs,
  lib,
  config,
  git,
  ssh,
  ...
}:

let
  fallbackProfileName = git.fallback;
  profileNames = builtins.attrNames git.profiles;
  dirsOf =
    profile:
    let
      d = git.profiles.${profile}.dirs or [ "${config.home.homeDirectory}/git/github.com/${profile}" ];
    in
    if builtins.isList d then d else [ d ];

  ensureGlob = dir: if lib.hasSuffix "/**" dir then dir else "${dir}/**";

  generateSshMatchblocks =
    profileNames:
    builtins.listToAttrs (
      map (profileName: {
        name = "github.com-${profileName}";
        value = {
          hostname = "github.com";
          user = "git";
          identityFile = "${config.sops.secrets."ssh/${profileName}/private".path}";
          identitiesOnly = true;
          forwardAgent = true;
          addKeysToAgent = "yes";
        };
      }) profileNames
    );

  generateGitIncludes =
    profileNames:
    builtins.concatMap (
      profileName:
      map (dir: {
        condition = "gitdir:${ensureGlob dir}";
        path = "${config.sops.templates."gitprofile-${profileName}".path}";
      }) (dirsOf profileName)
    ) profileNames;

  homelabSshHosts = [
    {
      match = "nixos-ry6a";
      hostname = "nixos-ry6a";
      user = "k8s";
      key = "k8s";
    }
    {
      match = "ry4a";
      hostname = "ry4a";
      user = "k8s";
      key = "ry4a";
    }
    {
      match = "ry6b";
      hostname = "ry6b";
      user = "k8s";
      key = "ry6b";
    }
  ];

  generateHomelabSshMatchblocks =
    hosts:
    builtins.listToAttrs (
      lib.filter (value: value != null) (
        map (
          host:
          if lib.elem host.key ssh.keys then
            {
              name = host.match;
              value = {
                inherit (host) hostname user;
                identityFile = "${config.sops.secrets."ssh/${host.key}/private".path}";
                identitiesOnly = true;
                forwardAgent = true;
                addKeysToAgent = "yes";
              };
            }
          else
            null
        ) hosts
      )
    );
in
{
  options = {
    homeModules.developer.enable = lib.mkEnableOption "enables developer tools";
  };

  config = lib.mkIf config.homeModules.developer.enable {
    # development tools
    home.packages = with pkgs; [
      # cli tools
      lazygit # tui git client
      pet # snippet manager
      yq # cli yaml processor
      jq # cli json processor
      curl # cli http client
      envsubst # cli env var substitution
      fd # user friendly alternative to find
      neovide
      nil # nix
      nixd
      # languages
      nodejs_22
      python314
      go
      zig
      rustup
      coursier
      # doc
      pandoc
      # github cli
      gh
      # devenv
      devenv
      # duckdb
      duckdb
      # used to notify of theme changes
      dark-mode-notify
      # gitbutler cli
      gitbutler-cli
    ];

    # tooling management
    programs.mise = {
      enable = true;
      enableZshIntegration = false;
      globalConfig = {
        settings = {
          pipx_uvx = true;
          idiomatic_version_file_enable_tools = [ ];
        };

        tools = {
          # none!
        };
      };
    };

    # SSH configuration using git profiles
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks =
        (generateSshMatchblocks profileNames) // (generateHomelabSshMatchblocks homelabSshHosts);
    };

    # every programmers best friend
    programs.git = {
      enable = true;
      package = pkgs.gitFull;
      ignores = [ "*.swp" ];
      includes =
        (
          if fallbackProfileName != null && fallbackProfileName != "" then
            [ { path = config.sops.templates."gitprofile-${fallbackProfileName}".path; } ]
          else
            [ ]
        )
        ++ generateGitIncludes profileNames;

      settings = {
        init.defaultBranch = "main";
        gpg.format = "ssh";
        core = {
          editor = "vim";
          autocrlf = "input";
        };
        user = {
          useConfigOnly = true;
        };
        pull.rebase = true;
        push = {
          default = "current";
          autoSetupRemote = true;
        };
        rebase.autoStash = true;
        branch.sort = "-committerdate";
      };
    };

    programs.zsh.initContent = lib.mkAfter ''
      # Load SOPS SSH keys into agent
      ${lib.concatMapStringsSep "\n" (key: ''
        if [[ -f "${config.sops.secrets."ssh/${key}/private".path}" ]]; then
           ssh-add "${config.sops.secrets."ssh/${key}/private".path}" >/dev/null 2>&1 || true
        fi
      '') ssh.keys}
    '';

    programs.sesh = {
      enable = true;
      enableAlias = true;
      enableTmuxIntegration = true;
      settings = builtins.fromTOML (builtins.readFile "${self}/config/sesh/sesh.toml");
    };

    programs.gh-dash = {
      enable = true;
      settings = {
        repoPaths = {
          "lunarway/hubble-continuum" = "/Users/kisw/git/github.com/lunarway/hubble-continuum/review";
          "lunarway/hubble-flink-platform" =
            "/Users/kisw/git/github.com/lunarway/hubble-flink-platform/review";
          "lunarway/lunar-way-hubble-transformations" =
            "/Users/kisw/git/github.com/lunarway/lunarway/lunar-way-hubble-transformations/review";
        };
      };
    };
  };
}
