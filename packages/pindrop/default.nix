{
  curl,
  jq,
  lib,
  nix-update,
  stdenvNoCC,
  fetchurl,
  writeShellScript,
  _7zz,
  makeBinaryWrapper,
}:

stdenvNoCC.mkDerivation {
  pname = "pindrop";
  version = "1.22.5";

  src = fetchurl {
    url = "https://github.com/watzon/pindrop/releases/download/v1.22.5/Pindrop.dmg";
    hash = "sha256-XVfrXHFU0P5csYwLDmKILxVxWu4Fz3xSLXL+DdXyinQ=";
  };

  # -snld prevents dangerous symbolic link paths; exclude APFS metadata.
  unpackCmd = "7zz x -snld -xr'!*:com.apple.*' $curSrc";
  nativeBuildInputs = [
    _7zz
    makeBinaryWrapper
  ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R Pindrop/Pindrop.app $out/Applications/

    mkdir -p $out/bin
    makeBinaryWrapper \
      "$out/Applications/Pindrop.app/Contents/MacOS/Pindrop" \
      "$out/bin/pindrop"

    runHook postInstall
  '';

  # Preserve the notarized signature of the bundled app.
  dontFixup = true;

  passthru.updateScript = writeShellScript "update-pindrop" ''
    set -euo pipefail
    tag="$(${lib.getExe curl} -fsSL https://api.github.com/repos/watzon/pindrop/releases?per_page=100 |
      ${lib.getExe jq} -r '[.[] | select((.draft | not) and (.prerelease | not)) | .tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))][0]')"
    test -n "$tag"
    version="''${tag#v}"
    ${lib.getExe nix-update} --flake --version="$version" pindrop
    echo "Updated pindrop to $tag"
  '';

  meta = {
    description = "Native macOS dictation app";
    homepage = "https://github.com/watzon/pindrop";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "pindrop";
    platforms = lib.platforms.darwin;
  };
}
