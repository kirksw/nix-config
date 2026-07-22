{
  lib,
  writeShellApplication,
  writeShellScript,
  runCommand,
  fetchFromGitHub,
  uv,
  python312,
  git,
  nodejs_22,
  tmux,
}:

let
  versions = lib.importJSON ./versions.json;
  inherit (versions.omnigent) version rev;
  src = fetchFromGitHub {
    owner = "omnigent-ai";
    repo = "omnigent";
    inherit rev;
    hash = "sha256-NjSVwykJXvEcLwkrDofPI3yI2Gb55kKE+XcicHkxH3M=";
  };
  patchedSrc = runCommand "omnigent-${version}-patched-source" { } ''
    cp -R ${src} $out
    chmod -R u+w $out
    substituteInPlace $out/omnigent/runner/app.py \
      --replace 'command="claude",' 'command=os.environ.get("OMNIGENT_CLAUDE_BIN", "claude"),' \
      --replace 'env=build_native_claude_terminal_env(claude_config),' 'env={**build_native_claude_terminal_env(claude_config), "CLAUDE_CONFIG_DIR": os.environ.get("CLAUDE_CONFIG_DIR", str(Path.home() / ".claude")), **({"CLAUDE_EXECUTABLE_PATH": os.environ["OMNIGENT_CLAUDE_BIN"]} if os.environ.get("OMNIGENT_CLAUDE_BIN") else {})},'
  '';
in
writeShellApplication {
  name = "omnigent";
  runtimeInputs = [
    uv
    python312
    git
    nodejs_22
    tmux
  ];

  text = ''
    export UV_PYTHON_DOWNLOADS="''${UV_PYTHON_DOWNLOADS:-never}"
    export UV_PYTHON="''${UV_PYTHON:-${python312}/bin/python3}"

    if [ -z "''${OMNIGENT_UV_FROM:-}" ]; then
      _omnigent_src="''${XDG_CACHE_HOME:-$HOME/.cache}/omnigent-patched-source-${rev}"
      if [ ! -d "$_omnigent_src" ]; then
        rm -rf "$_omnigent_src.tmp"
        cp -R ${patchedSrc} "$_omnigent_src.tmp"
        chmod -R u+w "$_omnigent_src.tmp"
        mv "$_omnigent_src.tmp" "$_omnigent_src"
      fi
      export OMNIGENT_UV_FROM="$_omnigent_src"
    fi

    exec ${lib.getExe uv} tool run \
      --python "$UV_PYTHON" \
      --from "$OMNIGENT_UV_FROM" \
      omnigent "$@"
  '';

  passthru = {
    inherit version;

    updateScript = writeShellScript "update-omnigent" ''
            set -euo pipefail

            version_json="$repo_root/packages/omnigent/versions.json"
            version="$(${lib.getExe python312} - <<'PY'
      import json
      import urllib.request

      request = urllib.request.Request(
          "https://api.github.com/repos/omnigent-ai/omnigent/releases/latest",
          headers={"User-Agent": "nix-update-omnigent"},
      )
      with urllib.request.urlopen(request) as response:
          tag = json.load(response)["tag_name"]
      print(tag.removeprefix("v"))
      PY
            )"
            tag="v$version"
            read -r rev _ < <(${lib.getExe git} ls-remote https://github.com/omnigent-ai/omnigent.git "refs/tags/$tag^{}")

            ${lib.getExe python312} - "$version_json" "$version" "$rev" <<'PY'
      import json
      import sys
      from pathlib import Path

      path = Path(sys.argv[1])
      version, rev = sys.argv[2:]
      data = json.loads(path.read_text())
      data.setdefault("formatVersion", 1)
      data.setdefault("omnigent", {}).update(version=version, rev=rev)
      path.write_text(json.dumps(data, indent=2) + "\n")
      PY

            echo "Updated omnigent to version $version (rev $rev)"
    '';
  };

  meta = {
    description = "Meta-harness for Claude Code, Codex, Pi, and custom AI agents";
    homepage = "https://github.com/omnigent-ai/omnigent";
    license = lib.licenses.asl20;
    mainProgram = "omnigent";
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.kirksw ];
  };
}
