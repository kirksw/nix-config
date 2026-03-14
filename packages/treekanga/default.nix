{
  lib,
  stdenv,
  fetchzip,
  makeWrapper,
  testers,
}:

let
  versions = lib.importJSON ./versions.json;
  arch = stdenv.hostPlatform.parsed.cpu.name;
  # proton use macos designation instead of darwin
  os = if stdenv.hostPlatform.isDarwin then "macos" else stdenv.hostPlatform.parsed.kernel.name;

  supportedCombinations = versions.treekangaVersions.urls or { };
  isSupported = supportedCombinations ? ${os} && supportedCombinations.${os} ? ${arch};
  versionInfo =
    if isSupported then
      versions.treekangaVersions.urls.${os}.${arch}
    else
      throw "Unsupported platform: ${os}-${arch}";

  inherit (versionInfo) url hash;
  inherit (versions.treekangaVersions) version;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "treekanga";
  inherit version;

  src = fetchzip {
    inherit url;
    sha256 = hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;

  postUnpack = ''
    echo "=== postUnpack: PWD=$PWD ==="
    ls -la
    echo "=== tree (maxdepth 4) ==="
    find . -maxdepth 4 -print
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 treekanga $out/bin/treekanga

    runHook postInstall
  '';

  passthru = {
    tests.version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "treekanga --version";
    };
    # updateScript = writeShellScript "update-version" ''
    #   set -euo pipefail
    #   ${lib.getExe curl} -fsSL -o ${./versions.json} \
    #     ???
    # '';
  };

  meta = {
    description = "Command-line interface for Proton Pass";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    license = lib.licenses.gpl3Only;
    maintainers = [ lib.maintainers.kirksw ];
    mainProgram = "treekanga";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
