{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  testers,
}:

let
  versions = lib.importJSON ./versions.json;
  os = stdenvNoCC.hostPlatform.parsed.kernel.name;
  arch = stdenvNoCC.hostPlatform.parsed.cpu.name;
  supportedCombinations = versions.terminalBrowserVersions.urls;
  isSupported = supportedCombinations ? ${os} && supportedCombinations.${os} ? ${arch};
  versionInfo =
    if isSupported then
      supportedCombinations.${os}.${arch}
    else
      throw "terminal-browser does not support ${os}-${arch}";

  inherit (versionInfo) url hash;
  inherit (versions.terminalBrowserVersions) version;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "terminal-browser";
  inherit version;

  src = fetchurl {
    inherit url hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  sourceRoot = "terminal-browser";
  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/terminal-browser"
    cp -R . "$out/libexec/terminal-browser"
    makeWrapper "$out/libexec/terminal-browser/bin/terminal-browser" "$out/bin/terminal-browser"

    runHook postInstall
  '';

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "terminal-browser --version";
    version = "v${version}";
  };

  meta = {
    description = "Browser that runs inside a terminal";
    homepage = "https://github.com/zenbu-labs/terminal-browser";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.kirksw ];
    mainProgram = "terminal-browser";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
