{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  writeShellScript,
  curl,
  jq,
  nix,
  bubblewrap,
  socat,
}:

let
  versions = lib.importJSON ./versions.json;
  inherit (versions.claudeCode) version hashes;

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  src = fetchurl {
    url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${platformSuffix}/claude";
    hash = hashes.${platform};
  };

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/claude"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/claude" \
      --argv0 claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set-default DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 ${lib.optionalString stdenv.hostPlatform.isLinux "--prefix PATH : ${
        lib.makeBinPath [
          bubblewrap
          socat
        ]
      }"}
  '';

  passthru.updateScript = writeShellScript "update-claude-code" ''
    set -euo pipefail
    version_json="$repo_root/packages/claude-code/versions.json"
    base_url="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
    version="$(${lib.getExe curl} -fsSL "$base_url/latest" | tr -d '[:space:]')"
    manifest="$(${lib.getExe curl} -fsSL "$base_url/$version/manifest.json")"
    hashes="$(
      printf '%s' "$manifest" | ${lib.getExe jq} -r '{"x86_64-linux": .platforms."linux-x64".checksum, "aarch64-linux": .platforms."linux-arm64".checksum, "x86_64-darwin": .platforms."darwin-x64".checksum, "aarch64-darwin": .platforms."darwin-arm64".checksum} | to_entries[] | @tsv' |
        while IFS=$'\t' read -r nix_platform checksum; do
          hash="$(${lib.getExe nix} hash convert --hash-algo sha256 --to sri "$checksum")"
          ${lib.getExe jq} -n --arg platform "$nix_platform" --arg hash "$hash" '{($platform): $hash}'
        done | ${lib.getExe jq} -s add
    )"
    ${lib.getExe jq} -n --arg version "$version" --argjson hashes "$hashes" \
      '{formatVersion: 1, claudeCode: {version: $version, hashes: $hashes}}' > "$version_json"
    echo "Updated claude-code to version $version"
  '';

  meta = {
    description = "Anthropic Claude Code CLI";
    homepage = "https://claude.ai/code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
    platforms = builtins.attrNames platformMap;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
