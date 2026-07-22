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
  tailscale,
  testers,
}:

let
  versions = lib.importJSON ./versions.json;
  inherit (versions."9routerVersions") version hash npmDepsHash;
in
buildNpmPackage (finalAttrs: {
  pname = "9router";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/9router/-/9router-${version}.tgz";
    inherit hash;
  };

  # The published tarball does not bundle the package's own runtime
  # dependencies (enquirer, node-forge, node-machine-id, react, react-dom).
  # fetchNpmDeps resolves and fetches them at build time, then they are
  # materialised into node_modules during installPhase.
  inherit npmDepsHash;

  # The upstream tarball does not ship a package-lock.json. Vendoring one
  # keeps npmDepsHash stable and makes buildNpmPackage happy.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    chmod +w package-lock.json
  '';

  # The upstream postinstall script bootstraps ~/.9router/runtime with
  # native modules (better-sqlite3, systray2). That is not allowed in a
  # pure Nix build, and the runtime will lazy-install those bits into the
  # user's home dir on first launch.
  npmFlags = [ "--ignore-scripts" ];

  # The tarball ships pre-built Next.js artifacts under app/ but no
  # scripts/build-cli.js, so we must skip the npm build step.
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  # 9router's "Tailscale" tunnel feature shells out to a tailscale binary
  # (status --json, login, funnel) and optionally spawns tailscaled. Its
  # detection probes a hardcoded set of paths plus `which tailscale` using
  # the inherited PATH. Bundling the nixpkgs tailscale package and
  # prepending its bin dir to the wrapper's PATH makes `which tailscale`
  # resolve to it, and also ensures tailscaled is on PATH for the
  # enable/install flows.
  buildInputs = [ tailscale ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/9router
    cp -r ./. $out/lib/node_modules/9router/
    chmod +x $out/lib/node_modules/9router/cli.js

    # 9router hardcodes a private tailscaled socket at
    # $DATA_DIR/tailscale/tailscaled.sock, a hardcoded /opt/homebrew/bin
    # PATH prefix, and a `which brew` install branch. All three prevent
    # the bundled tailscale from talking to a host-managed tailscaled
    # (e.g. the nix-darwin LaunchDaemon at /var/run/tailscaled.socket) and
    # would have 9router try to install via Homebrew on macOS. Patch them
    # in place across the route bundles too (tailscale-check, tailscale-install)
    # which each ship their own inline copies of these constants.
    #
    # The socket path is platform-specific: macOS uses
    # /var/run/tailscaled.socket (Tailscale.app / nix-darwin default);
    # Linux systemd uses /var/run/tailscale/tailscaled.sock. We default to
    # the macOS path and fall back to the Linux one when that is missing.
    #
    # We also inject the bundled tailscale path into the hardcoded search
    # list `at` so the synchronous first-call fallback in 9router's ay()
    # finds the binary on its first call (it only runs `which tailscale`
    # asynchronously on a 10s cache and otherwise relies on these paths).
    SERVER=$out/lib/node_modules/9router/app/.next-cli-build/server

    # ponytail: upstream chunk names move; patch every bundled server JS file.
    while IFS= read -r f; do
      sed -i \
        -e 's|/opt/homebrew/bin:||g' \
        -e 's|"/opt/homebrew/bin/tailscale",||g' \
        -e 's|"which brew"|"which __9router_no_brew__"|g' \
        -e 's|g().join(ap,"tailscaled.sock")|"/var/run/tailscaled.socket"|g' \
        -e 's|"/usr/local/bin/tailscale",|"/usr/local/bin/tailscale","${tailscale}/bin/tailscale",|g' \
        "$f"
    done < <(find "$SERVER" -type f -name '*.js')

    mkdir -p $out/bin
    makeWrapper ${lib.getExe nodejs} $out/bin/9router \
      --prefix PATH : ${lib.makeBinPath [ tailscale ]} \
      --add-flags "$out/lib/node_modules/9router/cli.js"

    runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/9router --version

    runHook postInstallCheck
  '';
  doInstallCheck = stdenv.hostPlatform.canExecute stdenv.hostPlatform;

  passthru = {
    updateScript = writeShellScript "update-9router" ''
      set -euo pipefail
      version_json="$repo_root/packages/9router/versions.json"
      lock_file="$repo_root/packages/9router/package-lock.json"
      version="$(${nodejs_22}/bin/npm view 9router version --json | ${lib.getExe jq} -r .)"
      tarball="https://registry.npmjs.org/9router/-/9router-$version.tgz"
      source_hash="$(${lib.getExe nix} hash convert --hash-algo sha256 --to sri \
        $(${nix}/bin/nix-prefetch-url --type sha256 "$tarball" 2>&1 | tail -1))"
      tmp_dir="$(mktemp -d)"
      trap 'rm -rf "$tmp_dir"' EXIT
      ${lib.getExe curl} -fsSL "$tarball" -o "$tmp_dir/source.tgz"
      tar -xzf "$tmp_dir/source.tgz" -C "$tmp_dir" --strip-components=1
      rm -f "$tmp_dir/package-lock.json" "$tmp_dir/npm-shrinkwrap.json"
      (cd "$tmp_dir" && ${nodejs_22}/bin/npm install --package-lock-only --ignore-scripts)
      cp "$tmp_dir/package-lock.json" "$lock_file"
      old_npm_deps_hash="$(${lib.getExe jq} -r '."9routerVersions".npmDepsHash' "$version_json")"
      ${lib.getExe jq} -n --arg version "$version" --arg hash "$source_hash" --arg npmDepsHash "$old_npm_deps_hash" \
        '{formatVersion: 1, "9routerVersions": {version: $version, hash: $hash, npmDepsHash: $npmDepsHash}}' > "$version_json"
      set +e
      output="$(${nix}/bin/nix build ".#9router" --no-link --print-build-logs 2>&1)"
      status="$?"
      set -e
      if [ "$status" -eq 0 ]; then
        echo "Updated 9router to version $version (npmDepsHash unchanged)"
        exit 0
      fi
      npm_deps_hash="$(printf '%s\\n' "$output" | sed -n 's/.*got:[[:space:]]*//p' | tail -1)"
      if [ -z "$npm_deps_hash" ]; then
        printf '%s\\n' "$output" >&2
        echo "Could not determine npmDepsHash from nix build output" >&2
        exit "$status"
      fi
      tmp_json="$(mktemp)"
      ${lib.getExe jq} --arg npmDepsHash "$npm_deps_hash" '."9routerVersions".npmDepsHash = $npmDepsHash' "$version_json" > "$tmp_json"
      mv "$tmp_json" "$version_json"
      echo "Updated 9router to version $version"
    '';
    tests.version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "9router --version";
    };
  };

  meta = {
    description = "Unlimited free AI coding router connecting Claude Code, Codex, Cursor, Cline, Copilot, Antigravity to free Claude/GPT/Gemini via 40+ providers with auto-fallback";
    homepage = "https://github.com/decolua/9router";
    license = lib.licenses.mit;
    mainProgram = "9router";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
