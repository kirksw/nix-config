{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
  makeBinaryWrapper,
  nix-update-script,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cmux";
  version = "browser-apple-review-20260722.1";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    url = "https://github.com/manaflow-ai/cmux/releases/download/v${finalAttrs.version}/cmux-macos.dmg";
    hash = "sha256-pq5qsvmBc+W/1Nz0a0Up/iOpynX9yHkxDX5t6CZpPnU=";
  };

  # -snld prevents "ERROR: Dangerous symbolic link path was ignored".
  # -xr'!*:com.apple.*' avoids APFS extended attributes becoming files.
  unpackCmd = "7zz x -snld -xr'!*:com.apple.*' $curSrc";

  nativeBuildInputs = [
    _7zz
    makeBinaryWrapper
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R cmux.app $out/Applications/

    mkdir -p $out/bin
    makeBinaryWrapper \
      "$out/Applications/cmux.app/Contents/MacOS/cmux" \
      "$out/bin/cmux"

    runHook postInstall
  '';

  # Preserve the notarized signature of the bundled binaries and resources.
  dontFixup = true;

  passthru.updateScript = nix-update-script {
    attrPath = "cmux";
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Native macOS terminal built on Ghostty, designed for AI coding agents";
    longDescription = ''
      cmux is a macOS-native terminal application built on Ghostty that
      provides vertical tabs, notification rings, an in-app browser, and
      first-class support for AI coding agents such as Claude Code.
      It exposes scriptable CLI and socket APIs.
    '';
    homepage = "https://cmux.com";
    changelog = "https://github.com/manaflow-ai/cmux/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "cmux";
    maintainers = with lib.maintainers; [ imcvampire ];
    platforms = lib.platforms.darwin;
  };
})
