{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.darwinModules.landing;

  renderTile = tile: ''
    <a class="tile" href="${tile.url}">
      <strong>${tile.name}</strong>
      ${lib.optionalString (tile.description != "") "<span>${tile.description}</span>"}
      <code>${tile.url}</code>
    </a>
  '';

  groups = lib.unique (map (tile: tile.group) cfg.tiles);

  renderSection =
    group:
    let
      groupTiles = builtins.filter (tile: tile.group == group) cfg.tiles;
    in
    ''
      <section>
        <h2>${group}</h2>
        <div class="grid">
          ${lib.concatMapStrings renderTile groupTiles}
        </div>
      </section>
    '';

  landingSite = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>landing</title>
        <style>
          :root {
            color-scheme: dark;
            --bg: #0b1020;
            --panel: #121a2f;
            --panel-border: #253150;
            --text: #e8edf7;
            --muted: #9daccc;
            --accent: #7cc4ff;
          }
          * { box-sizing: border-box; }
          body {
            margin: 0;
            font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background: linear-gradient(180deg, #0b1020 0%, #11182c 100%);
            color: var(--text);
          }
          main {
            max-width: 1100px;
            margin: 0 auto;
            padding: 48px 24px 64px;
          }
          h1 {
            margin: 0 0 8px;
            font-size: 40px;
            line-height: 1.1;
          }
          p {
            margin: 0;
            color: var(--muted);
            font-size: 16px;
          }
          section {
            margin-top: 32px;
          }
          h2 {
            margin: 0 0 14px;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            color: var(--muted);
          }
          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 14px;
          }
          .tile {
            display: block;
            min-height: 132px;
            padding: 18px;
            border-radius: 12px;
            border: 1px solid var(--panel-border);
            background: rgba(18, 26, 47, 0.94);
            color: inherit;
            text-decoration: none;
            transition: transform 120ms ease, border-color 120ms ease;
          }
          .tile:hover {
            transform: translateY(-1px);
            border-color: var(--accent);
          }
          .tile strong {
            display: block;
            font-size: 18px;
            margin-bottom: 8px;
          }
          .tile span {
            display: block;
            color: var(--muted);
            margin-bottom: 14px;
            line-height: 1.4;
          }
          .tile code {
            color: var(--accent);
            font-size: 13px;
            word-break: break-word;
          }
        </style>
      </head>
      <body>
        <main>
          <h1>landing</h1>
          <p>Small dashboard for the URLs you forget.</p>
          ${lib.concatMapStrings renderSection groups}
        </main>
      </body>
    </html>
  '';
in
{
  options.darwinModules.landing = {
    enable = lib.mkEnableOption "enables local landing dashboard";

    tiles = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption { type = lib.types.str; };
            url = lib.mkOption { type = lib.types.str; };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "Services";
            };
          };
        }
      );
      default = [
        {
          name = "Omnigent Personal";
          url = "http://127.0.0.1:6767";
          description = "Personal local Omnigent server.";
          group = "AI";
        }
        {
          name = "Omnigent Work";
          url = "http://127.0.0.1:6768";
          description = "Work local Omnigent server.";
          group = "AI";
        }
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.postActivation.text = lib.mkAfter ''
      hosts_file=/etc/hosts
      start_marker="# nix-config landing start"
      end_marker="# nix-config landing end"
      tmp="$(mktemp)"

      ${pkgs.gawk}/bin/awk -v start="$start_marker" -v end="$end_marker" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
      ' "$hosts_file" > "$tmp"

      printf '\n%s\n127.0.0.1 landing\n%s\n' "$start_marker" "$end_marker" >> "$tmp"
      cat "$tmp" > "$hosts_file"
      rm -f "$tmp"
    '';

    launchd.daemons.landing = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.python3}/bin/python3"
          "-m"
          "http.server"
          "80"
          "--bind"
          "127.0.0.1"
          "--directory"
          "${landingSite}"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/Library/Logs/landing.log";
        StandardErrorPath = "/Library/Logs/landing.err.log";
      };
    };
  };
}
