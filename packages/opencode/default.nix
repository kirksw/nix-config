{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  writeShellScript,
  curl,
  jq,
  nix,
  unzip,
  fzf,
  ripgrep,
}:

let
  versions = lib.importJSON ./versions.json;
  inherit (versions.opencode) version hashes;

  platformMap = {
    x86_64-linux = {
      asset = "opencode-linux-x64.tar.gz";
      isZip = false;
    };
    aarch64-linux = {
      asset = "opencode-linux-arm64.tar.gz";
      isZip = false;
    };
    x86_64-darwin = {
      asset = "opencode-darwin-x64.zip";
      isZip = true;
    };
    aarch64-darwin = {
      asset = "opencode-darwin-arm64.zip";
      isZip = true;
    };
  };

  platform = stdenv.hostPlatform.system;
  platformInfo = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/${platformInfo.asset}";
    hash = hashes.${platform};
  };

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals platformInfo.isZip [ unzip ];
  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
  ''
  + lib.optionalString platformInfo.isZip ''
    unzip "$src"
  ''
  + lib.optionalString (!platformInfo.isZip) ''
    tar -xzf "$src"
  ''
  + ''
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 opencode "$out/bin/opencode"
    wrapProgram "$out/bin/opencode" --prefix PATH : ${
      lib.makeBinPath [
        fzf
        ripgrep
      ]
    }
    runHook postInstall
  '';

  passthru.updateScript = writeShellScript "update-opencode" ''
    set -euo pipefail
    version_json="$repo_root/packages/opencode/versions.json"
    version="$(${lib.getExe curl} -fsSL https://api.github.com/repos/anomalyco/opencode/releases/latest | ${lib.getExe jq} -r '.tag_name | ltrimstr("v")')"
    assets_json='{"x86_64-linux":"opencode-linux-x64.tar.gz","aarch64-linux":"opencode-linux-arm64.tar.gz","x86_64-darwin":"opencode-darwin-x64.zip","aarch64-darwin":"opencode-darwin-arm64.zip"}'
    hashes="$(
      printf '%s' "$assets_json" | ${lib.getExe jq} -r 'to_entries[] | @tsv' |
        while IFS=$'\t' read -r nix_platform asset; do
          url="https://github.com/anomalyco/opencode/releases/download/v$version/$asset"
          hash="$(${lib.getExe nix} hash convert --hash-algo sha256 --to sri \
            $(${nix}/bin/nix-prefetch-url --type sha256 "$url" 2>&1 | tail -1))"
          ${lib.getExe jq} -n --arg platform "$nix_platform" --arg hash "$hash" '{($platform): $hash}'
        done | ${lib.getExe jq} -s add
    )"
    ${lib.getExe jq} -n --arg version "$version" --argjson hashes "$hashes" \
      '{formatVersion: 1, opencode: {version: $version, hashes: $hashes}}' > "$version_json"
    echo "Updated opencode to version $version"
  '';

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = builtins.attrNames platformMap;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
