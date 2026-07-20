{
  alsa-lib,
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  stdenvNoCC,
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
