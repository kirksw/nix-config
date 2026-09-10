{ buildNpmPackage }:

buildNpmPackage {
  npmDepsFetcherVersion = 2;
  pname = "pi-fast-mode";
  version = "1.0.0";
  src = ../../agents/packages/pi-fast-mode;
  npmDepsHash = "sha256-q1vCoxG0wg4qqvJnWWmtfIsI2TuP7hZ8TY8oHmLUcDU=";
  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R . "$out"
    runHook postInstall
  '';
}
