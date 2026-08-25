{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
}:

let
  versions = lib.importJSON ./versions.json;
  os = stdenvNoCC.hostPlatform.parsed.kernel.name;
  arch = stdenvNoCC.hostPlatform.parsed.cpu.name;
  supportedCombinations = versions.terminalCodeVersions.urls;
  isSupported = supportedCombinations ? ${os} && supportedCombinations.${os} ? ${arch};
  versionInfo =
    if isSupported then
      supportedCombinations.${os}.${arch}
    else
      throw "terminal-code does not support ${os}-${arch}";

  inherit (versionInfo) url hash;
  inherit (versions.terminalCodeVersions) version;
in
stdenvNoCC.mkDerivation {
  pname = "terminal-code";
  inherit version;

  src = fetchurl {
    inherit url hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  sourceRoot = "tode";
  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;

  postPatch = ''
    substituteInPlace dist/runtime/release.js \
      --replace-fail \
        'return { bin: writeLauncher(VENDORED), root: VENDORED, version, source: "vendored" };' \
        'return { bin: node_path_1.default.join(VENDORED, "bin", "terminal-browser"), root: VENDORED, version, source: "vendored" };'

    browser_environment=$(cat <<'EOF'
    export ELECTRON_RUN_AS_NODE=1
    TODE_DATA_ROOT="''${XDG_DATA_HOME:-$HOME/.local/share}/tode"
    TODE_STATE_ROOT="''${XDG_STATE_HOME:-$HOME/.local/state}/tode"
    TODE_CACHE_ROOT="''${XDG_CACHE_HOME:-$HOME/.cache}/tode"
    export XDG_DATA_HOME="''${TODE_BROWSER_DATA:-$TODE_DATA_ROOT/browser/share}"
    export XDG_STATE_HOME="''${TODE_BROWSER_STATE:-$TODE_STATE_ROOT/browser/state}"
    export XDG_CACHE_HOME="''${TODE_BROWSER_CACHE:-$TODE_CACHE_ROOT/browser}"
    if [ -n "''${TODE_BROWSER_RUN:-}" ]; then export XDG_RUNTIME_DIR="$TODE_BROWSER_RUN"; fi
    export TERMINAL_BROWSER_APPDATA="''${TODE_BROWSER_APPDATA:-$TODE_DATA_ROOT/browser/chromium}"
    EOF
    )
    substituteInPlace vendor/terminal-browser/bin/terminal-browser \
      --replace-fail 'export ELECTRON_RUN_AS_NODE=1' "$browser_environment"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/tode"
    cp -R . "$out/libexec/tode"
    makeWrapper "$out/libexec/tode/bin/tode" "$out/bin/tode" \
      --set TODE_INSTALL_ROOT "$out/libexec/tode"

    runHook postInstall
  '';

  meta = {
    description = "VS Code inside a terminal";
    homepage = "https://github.com/zenbu-labs/terminal-code";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.kirksw ];
    mainProgram = "tode";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
