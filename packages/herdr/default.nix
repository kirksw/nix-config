{
  bash,
  coreutils,
  curl,
  fetchFromGitHub,
  git,
  gnugrep,
  herdr,
  jq,
  lib,
  nix,
  python3,
  rustPlatform,
  stdenv,
  writeShellScript,
  zig_0_15,
}:

let
  version = "0.8.2";
  src = fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    tag = "v${version}";
    # update-hash: source
    hash = "sha256-sEGIN3dLZasaHob3EHscWBCIQHflMQVchYmzgsETDk4=";
  };
in
herdr.overrideAttrs (old: {
  inherit version src;

  cargoDeps = rustPlatform.fetchCargoVendor {
    pname = "herdr";
    inherit version src;
    # update-hash: cargo
    hash = "sha256-4VThqPwYYEsGvaOKjBeL6XAC5bnNWB6oUMWP/uXc/UQ=";
  };

  zigDeps = zig_0_15.fetchDeps {
    pname = "herdr";
    inherit version;
    src = "${src}/vendor/libghostty-vt";
    fetchAll = true;
    # update-hash: zig
    hash = "sha256-PnM+hZIlLyQwK8vJgd/Bhjt1lNIz06T8FahwliRmMrY=";
  };

  postInstall = ''
    mkdir -p $out/share/herdr/skills/herdr
    "$out/bin/herdr" --skill > $out/share/herdr/skills/herdr/SKILL.md
    installShellCompletion --cmd herdr \
      --bash <("$out/bin/herdr" completion bash) \
      --fish <("$out/bin/herdr" completion fish) \
      --zsh <("$out/bin/herdr" completion zsh)
  '';

  passthru = (old.passthru or { }) // {
    updateScript = writeShellScript "update-herdr" ''
      set -euo pipefail

      repo_root="''${repo_root:-$(${lib.getExe git} rev-parse --show-toplevel)}"
      cd "$repo_root"

      release_json="$(${lib.getExe curl} -fsSL 'https://api.github.com/repos/ogulcancelik/herdr/releases?per_page=100')"
      tag="$(printf '%s' "$release_json" | ${lib.getExe jq} -r '
        [
          .[]
          | select((.draft | not) and (.prerelease | not))
          | .tag_name as $tag
          | ($tag | capture("^v(?<major>[0-9]+)\\.(?<minor>[0-9]+)\\.(?<patch>[0-9]+)$"))
            + { tag: $tag }
          | .major |= tonumber
          | .minor |= tonumber
          | .patch |= tonumber
        ]
        | max_by([.major, .minor, .patch])
        | .tag // empty
      ')"
      test -n "$tag"
      next_version="''${tag#v}"

      ${lib.getExe python3} - "$next_version" "${version}" <<'PY'
      import sys

      next_version, current_version = (
          tuple(map(int, value.split("."))) for value in sys.argv[1:]
      )
      if next_version < current_version:
          raise SystemExit(
              f"refusing to downgrade Herdr from {sys.argv[2]} to {sys.argv[1]}"
          )
      PY

      if [ "$next_version" = "${version}" ]; then
        echo "Herdr is already at the latest stable release ($tag)."
        exit 0
      fi

      files=(
        packages/herdr/default.nix
        modules/home/programs/ai-agents.nix
        hosts/nixos/ry4a/agent-microvms.nix
      )
      backup_root="$(${coreutils}/bin/mktemp -d)"
      success=0
      cleanup() {
        status="$?"
        if [ "$success" -ne 1 ]; then
          echo "Herdr update failed; restoring pinned files." >&2
          for file in "''${files[@]}"; do
            ${coreutils}/bin/cp "$backup_root/$file" "$file"
          done
        fi
        ${coreutils}/bin/rm -rf "$backup_root"
        trap - EXIT
        exit "$status"
      }
      trap cleanup EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM HUP

      for file in "''${files[@]}"; do
        ${coreutils}/bin/mkdir -p "$backup_root/$(${coreutils}/bin/dirname "$file")"
        ${coreutils}/bin/cp "$file" "$backup_root/$file"
      done

      export HERDR_UPDATE_REPO_ROOT="$repo_root"
      expression_file="$backup_root/herdr.nix"
      cat > "$expression_file" <<EOF
      let
        repoRoot = builtins.getEnv "HERDR_UPDATE_REPO_ROOT";
        flake = builtins.getFlake ("git+file://" + repoRoot);
        pkgs = import flake.inputs.nixpkgs { system = "${stdenv.hostPlatform.system}"; };
      in
      pkgs.callPackage (builtins.toPath (repoRoot + "/packages/herdr")) { }
      EOF

      ${lib.getExe python3} - "$next_version" <<'PY'
      import pathlib
      import re
      import sys

      path = pathlib.Path("packages/herdr/default.nix")
      next_version = sys.argv[1]
      text = path.read_text()
      text, count = re.subn(
          r'(\n  version = ")[^"]+(";)',
          lambda match: match.group(1) + next_version + match.group(2),
          text,
          count=1,
      )
      if count != 1:
          raise SystemExit("expected one Herdr version assignment")
      path.write_text(text)
      PY

      set_hash() {
        label="$1"
        value="$2"
        ${lib.getExe python3} - "$label" "$value" <<'PY'
      import pathlib
      import re
      import sys

      label, value = sys.argv[1:]
      path = pathlib.Path("packages/herdr/default.nix")
      text = path.read_text()
      marker = f"# update-hash: {label}"
      pattern = re.compile(rf"({re.escape(marker)}\n\s*hash = )[^;]+;")
      text, count = pattern.subn(lambda match: match.group(1) + value + ";", text, count=1)
      if count != 1:
          raise SystemExit(f"expected one {label} hash marker")
      path.write_text(text)
      PY
      }

      refresh_hash() {
        label="$1"
        case "$label" in
          source) attribute="src" ;;
          cargo) attribute="cargoDeps" ;;
          zig) attribute="zigDeps" ;;
          *) echo "unknown Herdr hash target: $label" >&2; exit 1 ;;
        esac

        echo "Refreshing Herdr $label hash..."
        set_hash "$label" 'lib.fakeHash'
        log="$backup_root/$label-build.log"
        set +e
        ${lib.getExe nix} build \
          --impure \
          --no-link \
          --print-build-logs \
          --file "$expression_file" \
          "$attribute" \
          2>&1 | ${coreutils}/bin/tee "$log"
        status="''${PIPESTATUS[0]}"
        set -e
        if [ "$status" -eq 0 ]; then
          echo "expected a hash mismatch while updating Herdr $label" >&2
          exit 1
        fi
        got="$(${lib.getExe python3} - "$log" <<'PY'
      import pathlib
      import re
      import sys

      matches = re.findall(
          r"\bgot:\s+(sha256-[A-Za-z0-9+/=]+)",
          pathlib.Path(sys.argv[1]).read_text(),
      )
      print(matches[-1] if matches else "")
      PY
      )"
        if [ -z "$got" ]; then
          echo "could not determine the Herdr $label hash" >&2
          exit 1
        fi
        set_hash "$label" "\"$got\""
        echo "Recorded Herdr $label hash: $got"
      }

      refresh_hash source
      refresh_hash cargo
      refresh_hash zig

      echo "Refreshing Herdr Pi integration hash..."
      integration_url="https://raw.githubusercontent.com/ogulcancelik/herdr/$tag/src/integration/assets/pi/herdr-agent-state.ts"
      integration_hash="$(${lib.getExe nix} store prefetch-file --json "$integration_url" | ${lib.getExe jq} -r .hash)"
      test -n "$integration_hash"

      ${lib.getExe python3} - "$tag" "$integration_hash" <<'PY'
      import pathlib
      import re
      import sys

      tag, integration_hash = sys.argv[1:]
      files = [
          pathlib.Path("modules/home/programs/ai-agents.nix"),
          pathlib.Path("hosts/nixos/ry4a/agent-microvms.nix"),
      ]
      integration_url = (
          "https://raw.githubusercontent.com/ogulcancelik/herdr/"
          f"{tag}/src/integration/assets/pi/herdr-agent-state.ts"
      )
      url_pattern = re.compile(
          r"https://raw\.githubusercontent\.com/ogulcancelik/herdr/"
          r"v[^/]+/src/integration/assets/pi/herdr-agent-state\.ts"
      )
      hash_pattern = re.compile(
          r'(herdrPiIntegration\s*=\s*pkgs\.fetchurl\s*\{\s*'
          r'url\s*=\s*"[^"]+";\s*hash\s*=\s*")[^"]+(";)',
          re.DOTALL,
      )

      for path in files:
          text = path.read_text()
          text, url_count = url_pattern.subn(integration_url, text)
          text, hash_count = hash_pattern.subn(
              lambda match: match.group(1) + integration_hash + match.group(2),
              text,
          )
          if url_count != 1 or hash_count != 1:
              raise SystemExit(
                  f"expected one Herdr integration URL and hash in {path}; "
                  f"found URLs={url_count}, hashes={hash_count}"
              )
          path.write_text(text)
      PY

      echo "Building Herdr $tag..."
      herdr_output="$(${lib.getExe nix} build \
        --impure \
        --no-link \
        --print-build-logs \
        --print-out-paths \
        --file "$expression_file")"
      GREP=${lib.getExe gnugrep} \
        ${lib.getExe bash} ${../../scripts/check-herdr-cli.sh} "$herdr_output/bin/herdr"
      success=1
      echo "Updated Herdr to $tag."
    '';
  };
})
