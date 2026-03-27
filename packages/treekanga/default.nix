{
  lib,
  stdenv,
  fetchzip,
  makeWrapper,
  writeShellScript,
  curl,
  jq,
  nix,
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
    updateScript = writeShellScript "update-treekanga" ''
      set -euo pipefail

      VERSION_JSON="$repo_root/packages/treekanga/versions.json"
      RELEASE_JSON="$(${lib.getExe curl} -fsSL https://api.github.com/repos/garrettkrohn/treekanga/releases/latest)"
      VERSION="$(printf '%s' "$RELEASE_JSON" | ${lib.getExe jq} -r '.tag_name | ltrimstr("v")')"
      ASSETS="$(
        printf '%s' "$RELEASE_JSON" | ${lib.getExe jq} -r '
          .assets[]
          | select(.name | test("^treekanga_(Darwin|Linux)_(arm64|x86_64)\\.tar\\.gz$"))
          | [.name, .browser_download_url]
          | @tsv
        '
      )"

      if [[ -z "$ASSETS" ]]; then
        echo "No supported treekanga release assets found"
        exit 1
      fi

      URLS_JSON='{}'

      while IFS=$'\t' read -r name url; do
        [[ -n "$name" ]] || continue

        os_raw="$(printf '%s' "$name" | sed -E 's/^treekanga_([^_]+)_([^_]+)\.tar\.gz$/\1/')"
        arch_raw="$(printf '%s' "$name" | sed -E 's/^treekanga_([^_]+)_([^_]+)\.tar\.gz$/\2/')"

        case "$os_raw" in
          Darwin)
            os="macos"
            ;;
          Linux)
            os="linux"
            ;;
          *)
            echo "Skipping unsupported OS in asset: $name"
            continue
            ;;
        esac

        case "$arch_raw" in
          arm64)
            arch="aarch64"
            ;;
          x86_64)
            arch="x86_64"
            ;;
          *)
            echo "Skipping unsupported architecture in asset: $name"
            continue
            ;;
        esac

        echo "Fetching hash for $os/$arch..."
        hash="$(${lib.getExe nix} hash convert --hash-algo sha256 --to sri \
          $(${nix}/bin/nix-prefetch-url --unpack --type sha256 "$url" 2>&1 | tail -1))"

        URLS_JSON="$(
          printf '%s' "$URLS_JSON" | ${lib.getExe jq} \
            --arg os "$os" \
            --arg arch "$arch" \
            --arg url "$url" \
            --arg hash "$hash" \
            '.[$os] = (.[$os] // {}) | .[$os][$arch] = { url: $url, hash: $hash }'
        )"
      done <<< "$ASSETS"

      ${lib.getExe jq} -n \
        --arg version "$VERSION" \
        --argjson urls "$URLS_JSON" \
        '{
          formatVersion: 1,
          treekangaVersions: {
            version: $version,
            urls: $urls
          }
        }' > "$VERSION_JSON"

      echo "Updated treekanga to version $VERSION"
    '';
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
