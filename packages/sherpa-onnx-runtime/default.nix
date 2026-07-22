{
  alsa-lib,
  autoPatchelfHook,
  curl,
  fetchurl,
  jq,
  lib,
  stdenv,
  stdenvNoCC,
  nix-update,
  writeShellScript,
}:

stdenvNoCC.mkDerivation {
  pname = "sherpa-onnx-runtime";
  version = "1.13.2";

  src = fetchurl {
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.2/sherpa-onnx-v1.13.2-linux-x64-shared.tar.bz2";
    hash = "sha256-HvZ0FTX3r01p45T9RAqAcQgDbSbtT1QmYBkQGdpcDao=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    alsa-lib
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;

  passthru.updateScript = writeShellScript "update-sherpa-onnx-runtime" ''
    set -euo pipefail
    version="$(${lib.getExe curl} -fsSL 'https://api.github.com/repos/k2-fsa/sherpa-onnx/releases?per_page=100' |
      ${lib.getExe jq} -r '[.[] | select((.draft | not) and (.prerelease | not)) | .tag_name as $tag |
        select($tag | test("^v?[0-9]+\\.[0-9]+\\.[0-9]+$")) |
        select(any(.assets[]; .name == ("sherpa-onnx-v" + ($tag | ltrimstr("v")) + "-linux-x64-shared.tar.bz2"))) |
        ($tag | ltrimstr("v"))][0]')"
    test -n "$version"
    ${lib.getExe nix-update} --flake --version="$version" sherpa-onnx-runtime
    echo "Updated sherpa-onnx-runtime to v$version"
  '';

  installPhase = ''
    mkdir -p "$out"
    cp -R bin lib "$out/"
  '';

  meta = {
    description = "Sherpa-ONNX shared runtime for Linux x86_64";
    homepage = "https://github.com/k2-fsa/sherpa-onnx";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
