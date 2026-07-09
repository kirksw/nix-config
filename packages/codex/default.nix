{
  lib,
  stdenv,
  fetchurl,
  writeShellScript,
  nodejs_22,
  jq,
}:

let
  versions = lib.importJSON ./versions.json;
  inherit (versions.codex) version hashes;

  platformMap = {
    x86_64-linux = {
      npmPlatform = "linux-x64";
      vendor = "x86_64-unknown-linux-musl";
    };
    aarch64-linux = {
      npmPlatform = "linux-arm64";
      vendor = "aarch64-unknown-linux-musl";
    };
    x86_64-darwin = {
      npmPlatform = "darwin-x64";
      vendor = "x86_64-apple-darwin";
    };
    aarch64-darwin = {
      npmPlatform = "darwin-arm64";
      vendor = "aarch64-apple-darwin";
    };
  };

  platform = stdenv.hostPlatform.system;
  platformInfo = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-${platformInfo.npmPlatform}.tgz";
    hash = hashes.${platform};
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    tar -xzf "$src" -C "$out" --strip-components=3 "package/vendor/${platformInfo.vendor}"
    runHook postInstall
  '';

  passthru.updateScript = writeShellScript "update-codex" ''
    set -euo pipefail
    version_json="$repo_root/packages/codex/versions.json"
    version="$(${nodejs_22}/bin/npm view @openai/codex version --json | ${lib.getExe jq} -r .)"
    platform_json='{"x86_64-linux":"linux-x64","aarch64-linux":"linux-arm64","x86_64-darwin":"darwin-x64","aarch64-darwin":"darwin-arm64"}'
    hashes="$(
      printf '%s' "$platform_json" | ${lib.getExe jq} -r 'to_entries[] | @tsv' |
        while IFS=$'\t' read -r nix_platform npm_platform; do
          hash="$(${nodejs_22}/bin/npm view "@openai/codex@$version-$npm_platform" dist.integrity --json | ${lib.getExe jq} -r .)"
          ${lib.getExe jq} -n --arg platform "$nix_platform" --arg hash "$hash" '{($platform): $hash}'
        done | ${lib.getExe jq} -s add
    )"
    ${lib.getExe jq} -n --arg version "$version" --argjson hashes "$hashes" \
      '{formatVersion: 1, codex: {version: $version, hashes: $hashes}}' > "$version_json"
    echo "Updated codex to version $version"
  '';

  meta = {
    description = "OpenAI Codex CLI";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = builtins.attrNames platformMap;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
