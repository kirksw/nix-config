{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "sherpa-onnx-lessac-model";
  version = "2024-03-28";

  src = fetchurl {
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-high.tar.bz2";
    hash = "sha256-hhnSBMcAWGb+T0IBgd+nliKvamIiOJ8LCBjSrzHg2w4=";
  };

  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p "$out"
    cp -R ./* "$out/"
  '';

  meta = {
    description = "Pinned Piper en_US lessac high voice model for Sherpa-ONNX";
    homepage = "https://github.com/k2-fsa/sherpa-onnx";
    license = lib.licenses.cc-by-40;
    platforms = lib.platforms.unix;
  };
}
