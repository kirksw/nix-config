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

  herdrProjectPalette = pkgs.writeShellApplication {
    name = "herdr-project-palette";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.fzf
      pkgs.gawk
      pkgs.git
      pkgs.herdr
      pkgs.jq
    ];
    text = builtins.readFile ../../../scripts/herdr-project-palette.sh;
  };

  herdrSmartFocus = pkgs.writeShellApplication {
    name = "herdr-smart-focus";
    runtimeInputs = [
      pkgs.gnugrep
      pkgs.herdr
      pkgs.jq
    ];
    text = ''
      direction="$1"
      key="$2"
      pane_id="$(herdr pane current --current | jq -r '.result.pane.pane_id')"

      if herdr pane process-info --current | jq -r '.result.process_info.foreground_processes[].name' | grep -Eiq '^(g?view|n?vim?x?)(diff)?$|^tmux$'; then
        herdr pane send-keys "$pane_id" "$key"
      else
        herdr pane focus --current --direction "$direction"
      fi
    '';
  };
in
{
  options = {
    homeModules.developer.enable = lib.mkEnableOption "enables developer tools";
  };

  config = lib.mkIf config.homeModules.developer.enable {
    # development tools
    home.packages = with pkgs; [
      notesCli
      herdrProjectPalette
      herdrSmartFocus
      # cli tools
      lazygit # tui git client
      pet # snippet manager
      yq # cli yaml processor
      jq # cli json processor
      curl # cli http client
      envsubst # cli env var substitution
      fd # user friendly alternative to find
      herdr
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
      _1password-cli
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

    xdg.configFile."herdr/config.toml" = {
      force = true;
      text = ''
        [theme]
        name = "rose-pine"
        auto_switch = false

        [ui.toast]
        delivery = "herdr"

        [ui]
        show_agent_labels_on_pane_borders = true

        [keys]
        prefix = "ctrl+a"
        goto = ""
        focus_pane_left = ""
        focus_pane_down = ""
        focus_pane_up = ""
        focus_pane_right = ""
        previous_tab = "prefix+p"
        rename_tab = "prefix+comma"
        close_tab = "prefix+ampersand"
        split_vertical = "prefix+|"
        split_horizontal = "prefix+minus"
        zoom = "prefix+m"

        [[keys.command]]
        key = "cmd+p"
        type = "pane"
        command = "herdr-project-palette"

        [[keys.command]]
        key = "prefix+g"
        type = "pane"
        command = "herdr-project-palette ezgit"

        [[keys.command]]
        key = "ctrl+j"
        type = "shell"
        command = "herdr-smart-focus left ctrl+j"

        [[keys.command]]
        key = "ctrl+k"
        type = "shell"
        command = "herdr-smart-focus down ctrl+k"

        [[keys.command]]
        key = "ctrl+l"
        type = "shell"
        command = "herdr-smart-focus up ctrl+l"

        [[keys.command]]
        key = "ctrl+;"
        type = "shell"
        command = "herdr-smart-focus right ctrl+;"

        [[keys.command]]
        key = "prefix+j"
        type = "shell"
        command = "herdr pane resize --current --direction left --amount 5"

        [[keys.command]]
        key = "prefix+k"
        type = "shell"
        command = "herdr pane resize --current --direction down --amount 5"

        [[keys.command]]
        key = "prefix+l"
        type = "shell"
        command = "herdr pane resize --current --direction up --amount 5"

        [[keys.command]]
        key = "prefix+;"
        type = "shell"
        command = "herdr pane resize --current --direction right --amount 5"
      '';
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
