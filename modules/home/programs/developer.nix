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
          HostName = "github.com";
          User = "git";
          IdentityFile = "${config.sops.secrets."ssh/${profileName}/private".path}";
          IdentitiesOnly = true;
          ForwardAgent = true;
          AddKeysToAgent = "yes";
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
                HostName = host.hostname;
                User = host.user;
                IdentityFile = "${config.sops.secrets."ssh/${host.key}/private".path}";
                IdentitiesOnly = true;
                ForwardAgent = true;
                AddKeysToAgent = "yes";
              };
            }
          else
            null
        ) hosts
      )
    );

  notesCli = pkgs.writeShellScriptBin "notes-capture" ''
    set -euo pipefail

    usage() {
      cat <<'EOF'
Usage: n [--context CONTEXT] <note text>
       command | n [--context CONTEXT]
EOF
    }

    context=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --context)
          if [ "$#" -lt 2 ]; then
            echo "n: --context requires a value" >&2
            exit 1
          fi
          context="$2"
          shift 2
          ;;
        --help|-h)
          usage
          exit 0
          ;;
        --)
          shift
          break
          ;;
        -*)
          echo "n: unknown option: $1" >&2
          usage >&2
          exit 1
          ;;
        *)
          break
          ;;
      esac
    done

    body_file="$(mktemp)"
    cleanup() {
      rm -f "$body_file"
    }
    trap cleanup EXIT

    if [ "$#" -gt 0 ]; then
      printf '%s\n' "$*" > "$body_file"
    elif [ ! -t 0 ]; then
      cat > "$body_file"
    else
      usage >&2
      exit 1
    fi

    if [ ! -s "$body_file" ]; then
      echo "n: note body is empty" >&2
      exit 1
    fi

    repo_dir="''${NOTES_REPO_DIR:-$HOME/git/github.com/kirksw/notes}"

    if [ ! -d "$repo_dir/.git" ]; then
      echo "n: notes repo not found at $repo_dir" >&2
      exit 1
    fi

    timestamp="$(date '+%Y%m%d-%H%M%S')"
    year="$(date '+%Y')"
    month="$(date '+%m')"
    created_at="$(date '+%Y-%m-%dT%H:%M:%S%z' | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')"

    slug="$(
      tr '\n' ' ' < "$body_file" |
        tr '[:upper:]' '[:lower:]' |
        sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' |
        cut -c1-48 |
        sed -E 's/-+$//'
    )"

    if [ -z "$slug" ]; then
      slug="note"
    fi

    note_dir="$repo_dir/raw/inbox/$year/$month"
    note_rel_path="raw/inbox/$year/$month/$timestamp-$slug.md"
    note_path="$repo_dir/$note_rel_path"

    mkdir -p "$note_dir"

    {
      printf '%s\n' '---'
      printf '%s\n' 'type: micronote'
      printf 'created: %s\n' "$created_at"
      if [ -n "$context" ]; then
        printf 'context: %s\n' "$context"
      fi
      printf '%s\n' 'status: unprocessed'
      printf '%s\n' '---'
      printf '\n'
      cat "$body_file"
    } > "$note_path"

    git -C "$repo_dir" add -- "$note_rel_path"
    git -C "$repo_dir" commit --quiet --only -m "add note $timestamp-$slug" -- "$note_rel_path"

    printf '%s\n' "$note_rel_path"
  '';
in
{
  options = {
    homeModules.developer.enable = lib.mkEnableOption "enables developer tools";
  };

  config = lib.mkIf config.homeModules.developer.enable {
    # development tools
    home.packages = with pkgs; [
      notesCli
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
      marp-cli
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

    home.shellAliases = {
      n = "${notesCli}/bin/notes-capture";
      np = "${notesCli}/bin/notes-capture --context personal";
      nw = "${notesCli}/bin/notes-capture --context work";
    };

    # SSH configuration using git profiles
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = (generateSshMatchblocks profileNames) // (generateHomelabSshMatchblocks homelabSshHosts);
    };

    # every programmers best friend
    programs.git = {
      enable = true;
      package = pkgs.git;
      ignores = [ "*.swp" ];
      signing.format = null;
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
