{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  nodejs,
  testers,
}:

let
  versions = lib.importJSON ./versions.json;
  inherit (versions."9routerVersions") version hash;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "9router";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/9router/-/9router-${version}.tgz";
    inherit hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;

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
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

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
