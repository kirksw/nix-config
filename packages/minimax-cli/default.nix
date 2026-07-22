{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  writeShellScript,
  curl,
  jq,
  nix,
  nodejs,
  nodejs_22,
  stdenv,
  testers,
}:

let
  versions = lib.importJSON ./versions.json;
  inherit (versions.mmxCli) version hash npmDepsHash;
in
buildNpmPackage (finalAttrs: {
  pname = "mmx-cli";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/mmx-cli/-/mmx-cli-${version}.tgz";
    inherit hash;
  };

  inherit npmDepsHash;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    chmod +w package-lock.json
  '';

  npmFlags = [
    "--ignore-scripts"
    "--omit=dev"
  ];
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/mmx-cli
    cp -r ./. $out/lib/node_modules/mmx-cli/
    chmod +x $out/lib/node_modules/mmx-cli/dist/mmx.mjs

    mkdir -p $out/bin
    makeWrapper ${lib.getExe nodejs} $out/bin/mmx \
      --add-flags "$out/lib/node_modules/mmx-cli/dist/mmx.mjs"

    runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/mmx --version
    runHook postInstallCheck
  '';
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  passthru = {
    updateScript = writeShellScript "update-minimax-cli" ''
      set -euo pipefail
      version_json="$repo_root/packages/minimax-cli/versions.json"
      lock_file="$repo_root/packages/minimax-cli/package-lock.json"
      version="$(${nodejs_22}/bin/npm view mmx-cli version --json | ${lib.getExe jq} -r .)"
      tarball="https://registry.npmjs.org/mmx-cli/-/mmx-cli-$version.tgz"
      source_hash="$(${lib.getExe nix} hash convert --hash-algo sha256 --to sri \
        $(${nix}/bin/nix-prefetch-url --type sha256 "$tarball" 2>&1 | tail -1))"
      tmp_dir="$(mktemp -d)"
      trap 'rm -rf "$tmp_dir"' EXIT
      ${lib.getExe curl} -fsSL "$tarball" -o "$tmp_dir/source.tgz"
      tar -xzf "$tmp_dir/source.tgz" -C "$tmp_dir" --strip-components=1
      rm -f "$tmp_dir/package-lock.json" "$tmp_dir/npm-shrinkwrap.json"
      (cd "$tmp_dir" && ${nodejs_22}/bin/npm install --package-lock-only --ignore-scripts)
      cp "$tmp_dir/package-lock.json" "$lock_file"
      old_npm_deps_hash="$(${lib.getExe jq} -r '.mmxCli.npmDepsHash' "$version_json")"
      ${lib.getExe jq} -n --arg version "$version" --arg hash "$source_hash" --arg npmDepsHash "$old_npm_deps_hash" \
        '{formatVersion: 1, mmxCli: {version: $version, hash: $hash, npmDepsHash: $npmDepsHash}}' > "$version_json"
      set +e
      output="$(${nix}/bin/nix build ".#minimax-cli" --no-link --print-build-logs 2>&1)"
      status="$?"
      set -e
      if [ "$status" -eq 0 ]; then
        echo "Updated minimax-cli to version $version (npmDepsHash unchanged)"
        exit 0
      fi
      npm_deps_hash="$(printf '%s\\n' "$output" | sed -n 's/.*got:[[:space:]]*//p' | tail -1)"
      if [ -z "$npm_deps_hash" ]; then
        printf '%s\\n' "$output" >&2
        echo "Could not determine npmDepsHash from nix build output" >&2
        exit "$status"
      fi
      tmp_json="$(mktemp)"
      ${lib.getExe jq} --arg npmDepsHash "$npm_deps_hash" '.mmxCli.npmDepsHash = $npmDepsHash' "$version_json" > "$tmp_json"
      mv "$tmp_json" "$version_json"
      echo "Updated minimax-cli to version $version"
    '';
    tests.version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "mmx --version";
    };
  };

  meta = {
    description = "Official CLI for the MiniMax AI Platform";
    homepage = "https://platform.minimax.io/docs/token-plan/minimax-cli";
    license = lib.licenses.mit;
    mainProgram = "mmx";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
