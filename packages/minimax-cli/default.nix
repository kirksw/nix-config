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

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "mmx --version";
  };

  meta = {
    description = "Official CLI for the MiniMax AI Platform";
    homepage = "https://platform.minimax.io/docs/token-plan/minimax-cli";
    license = lib.licenses.mit;
    mainProgram = "mmx";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
