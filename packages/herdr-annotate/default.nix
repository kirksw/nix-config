{
  lib,
  stdenvNoCC,
  fetchzip,
  fetchurl,
  bun,
  bash,
}:
let
  tuiVersion = "0.6.0";
  targets = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "096d0c5abda862c173ac7379c606f8909768f43458333ac706bd6ede0424c8b7";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "caca14bab235dee26417bfa6b49fe70b7bf6b985af9ea4ad4cd6ba24f56cec31";
    };
  };
  platform = targets.${stdenvNoCC.hostPlatform.system};
  tui = fetchurl {
    url = "https://github.com/plannotator/plannotator-tui/releases/download/v${tuiVersion}/plannotator-tui-${platform.target}";
    sha256 = platform.hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "herdr-annotate";
  version = "0.3.0-unstable-2026-09-07";
  src = fetchzip {
    url = "https://github.com/plannotator/herdr-annotate/archive/53b6e3211a4103c3de9d361eb3f3bacc7426d23b.tar.gz";
    hash = "sha256-2KOSud8fRsPC8q13tg+OOkgg+HkdoGLdjWxpZgo2Rbo=";
  };
  nativeBuildInputs = [ bun ];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    bun test
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    destination="$out/share/herdr/plugins/annotate"
    mkdir -p "$destination"
    cp -R src scripts LICENSE herdr-plugin.toml plannotator-tui.version "$destination/"
    mkdir -p "$destination/bin"
    install -m 0755 ${tui} "$destination/bin/plannotator-tui.exe"
    printf '%s' '${tuiVersion}' > "$destination/bin/plannotator-tui.version"
    substituteInPlace "$destination/herdr-plugin.toml" \
      --replace-fail '"bun",' '"${bun}/bin/bun",' \
      --replace-fail '"bash",' '"${bash}/bin/bash",' \
      --replace-fail 'exec bash ' 'exec ${bash}/bin/bash '
    runHook postInstall
  '';
  meta = {
    description = "Herdr terminal annotations and document review with Plannotator TUI";
    homepage = "https://github.com/plannotator/herdr-annotate";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
}
