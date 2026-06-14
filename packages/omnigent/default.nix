{
  lib,
  writeShellApplication,
  writeShellScript,
  uv,
  python312,
  git,
  nodejs_22,
  tmux,
}:

let
  versions = lib.importJSON ./versions.json;
  inherit (versions.omnigent) version rev;
  packageUrl = "git+https://github.com/omnigent-ai/omnigent.git@${rev}";
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

    exec ${lib.getExe uv} tool run \
      --python "$UV_PYTHON" \
      --from "''${OMNIGENT_UV_FROM:-${packageUrl}}" \
      omnigent "$@"
  '';

  passthru = {
    inherit version;

    updateScript = writeShellScript "update-omnigent" ''
            set -euo pipefail

            version_json="$repo_root/packages/omnigent/versions.json"
            read -r rev _ < <(${lib.getExe git} ls-remote https://github.com/omnigent-ai/omnigent.git HEAD)

            ${lib.getExe python312} - "$version_json" "$rev" <<'PY'
      import json
      import sys
      from pathlib import Path

      path = Path(sys.argv[1])
      rev = sys.argv[2]
      data = json.loads(path.read_text())
      data.setdefault("formatVersion", 1)
      data.setdefault("omnigent", {})["rev"] = rev
      path.write_text(json.dumps(data, indent=2) + "\n")
      PY

            echo "Updated omnigent rev to $rev"
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
