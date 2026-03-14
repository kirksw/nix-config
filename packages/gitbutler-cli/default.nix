{
  lib,
  stdenv,
  fetchzip,
  writeShellScript,
  curl,
  jq,
  nix,
  testers,
}:

let
  versions = lib.importJSON ./versions.json;
  arch = stdenv.hostPlatform.parsed.cpu.name;
  os = if stdenv.hostPlatform.isDarwin then "macos" else stdenv.hostPlatform.parsed.kernel.name;

  supportedCombinations = versions.gitbutlerCliVersions.urls or { };
  isSupported = supportedCombinations ? ${os} && supportedCombinations.${os} ? ${arch};
  versionInfo =
    if isSupported then
      versions.gitbutlerCliVersions.urls.${os}.${arch}
    else
      throw "Unsupported platform: ${os}-${arch}";

  inherit (versionInfo) url hash;
  inherit (versions.gitbutlerCliVersions) version build;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "gitbutler-cli";
  version = "${version}-${build}";

  src = fetchzip {
    inherit url;
    sha256 = hash;
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 Contents/MacOS/gitbutler-tauri $out/bin/but
    install -Dm755 Contents/MacOS/gitbutler-git-askpass $out/bin/gitbutler-git-askpass
    install -Dm755 Contents/MacOS/gitbutler-git-setsid $out/bin/gitbutler-git-setsid

    runHook postInstall
  '';

  passthru = {
    tests.version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "but --version";
    };
    updateScript = writeShellScript "update-gitbutler-cli" ''
      set -euo pipefail

      VERSION_JSON="$repo_root/packages/gitbutler-cli/versions.json"

      # Fetch latest version info for aarch64
      AARCH64_INFO=$(${lib.getExe curl} -fsSL https://app.gitbutler.com/releases/release/darwin-aarch64/0.0.0)
      AARCH64_URL=$(echo "$AARCH64_INFO" | ${lib.getExe jq} -r '.url')
      VERSION=$(echo "$AARCH64_INFO" | ${lib.getExe jq} -r '.version')

      # Extract build number from URL
      BUILD=$(echo "$AARCH64_URL" | grep -oE '[0-9]+\-[0-9]+' | head -1 | cut -d'-' -f2)

      # Construct x86_64 URL
      X86_64_URL=$(echo "$AARCH64_URL" | sed 's/aarch64/x86_64/g')

      # Fetch hashes
      echo "Fetching hash for aarch64..."
      AARCH64_HASH=$(${lib.getExe nix} hash convert --hash-algo sha256 --to nix32 \
        $(nix-prefetch-url --unpack --type sha256 "$AARCH64_URL" 2>&1 | tail -1))

      echo "Fetching hash for x86_64..."
      X86_64_HASH=$(${lib.getExe nix} hash convert --hash-algo sha256 --to nix32 \
        $(nix-prefetch-url --unpack --type sha256 "$X86_64_URL" 2>&1 | tail -1))

      # Write new versions.json
      ${lib.getExe jq} -n \
        --arg version "$VERSION" \
        --arg build "$BUILD" \
        --arg aarch64_url "$AARCH64_URL" \
        --arg aarch64_hash "$AARCH64_HASH" \
        --arg x86_64_url "$X86_64_URL" \
        --arg x86_64_hash "$X86_64_HASH" \
        '{
          gitbutlerCliVersions: {
            version: $version,
            build: $build,
            urls: {
              macos: {
                aarch64: {
                  url: $aarch64_url,
                  hash: $aarch64_hash
                },
                x86_64: {
                  url: $x86_64_url,
                  hash: $x86_64_hash
                }
              }
            }
          }
        }' > "$VERSION_JSON"

      echo "Updated to version $VERSION (build $BUILD)"
    '';
  };

  meta = {
    description = "GitButler CLI - Modern Git interface with stacked branches, undo, and forge integration";
    homepage = "https://gitbutler.com";
    platforms = lib.platforms.darwin;
    license = lib.licenses.unfree;
    maintainers = [ lib.maintainers.kirksw ];
    mainProgram = "but";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
