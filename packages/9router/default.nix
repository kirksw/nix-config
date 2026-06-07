{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
  stdenv,
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

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/9router
    cp -r ./. $out/lib/node_modules/9router/
    chmod +x $out/lib/node_modules/9router/cli.js

    mkdir -p $out/bin
    makeWrapper ${lib.getExe nodejs} $out/bin/9router \
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
