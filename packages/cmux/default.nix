{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
  curl,
  jq,
  makeBinaryWrapper,
  nix-update,
  writeShellScript,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cmux";
  version = "0.64.22";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    url = "https://github.com/manaflow-ai/cmux/releases/download/v${finalAttrs.version}/cmux-macos.dmg";
    hash = "sha256-/RSNujUZ/n0wiEQInOTQYrF3ObpkViPwWPZ6ZHmM6iU=";
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

  passthru.updateScript = writeShellScript "update-cmux" ''
    set -euo pipefail
    tag="$(${lib.getExe curl} -fsSL 'https://api.github.com/repos/manaflow-ai/cmux/releases?per_page=100' |
      ${lib.getExe jq} -r '
        [ .[]
          | select(.draft | not)
          | select(.prerelease | not)
          | select(any(.assets[]; .name == "cmux-macos.dmg"))
        ]
        | sort_by(.published_at) | reverse | .[0].tag_name // empty
      ' )"
    test -n "$tag"
    version="''${tag#v}"
    ${lib.getExe nix-update} --flake --version="$version" cmux
    echo "Updated cmux to $tag"
  '';

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
