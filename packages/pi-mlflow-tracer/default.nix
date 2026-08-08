{
  buildNpmPackage,
  lib,
}:

buildNpmPackage {
  npmDepsFetcherVersion = 2;
  pname = "pi-mlflow-tracer";
  version = "1.0.0-local.1";

  src = ../../agents/packages/pi-mlflow-tracer;
  npmDepsHash = "sha256-thREaJsSd5RaEdyr530wAk0iR0xbKYffCswU+8vlRLY=";
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R . "$out"
    runHook postInstall
  '';
}
