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
  inherit (versions.omniroute) version hash npmDepsHash;
in
buildNpmPackage (finalAttrs: {
  pname = "omniroute";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/omniroute/-/omniroute-${version}.tgz";
    inherit hash;
  };

  inherit npmDepsHash;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    chmod +w package-lock.json
  '';

  npmFlags = [
    "--ignore-scripts"
    "--legacy-peer-deps"
  ];

  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/omniroute
    cp -r ./. $out/lib/node_modules/omniroute/
    chmod +x $out/lib/node_modules/omniroute/bin/*.mjs

    mkdir -p $out/bin
    makeWrapper ${lib.getExe nodejs} $out/bin/omniroute \
      --add-flags "$out/lib/node_modules/omniroute/bin/omniroute.mjs"
    makeWrapper ${lib.getExe nodejs} $out/bin/omniroute-reset-password \
      --add-flags "$out/lib/node_modules/omniroute/bin/reset-password.mjs"

    runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/omniroute --version

    runHook postInstallCheck
  '';
  doInstallCheck = stdenv.hostPlatform.canExecute stdenv.hostPlatform;

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "omniroute --version";
  };

  meta = {
    description = "Unified AI router with dashboard, OpenAI-compatible APIs, MCP, and auto fallback";
    homepage = "https://github.com/diegosouzapw/OmniRoute";
    license = lib.licenses.mit;
    mainProgram = "omniroute";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
