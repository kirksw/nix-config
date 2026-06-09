{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
}:

stdenvNoCC.mkDerivation {
  pname = "model-bench";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/model-bench"
    cp -R src challenges fixtures tier-overrides.toml README.md "$out/share/model-bench/"

    makeWrapper ${lib.getExe python3} "$out/bin/model-bench" \
      --set MODEL_BENCH_DATA_DIR "$out/share/model-bench" \
      --set PYTHONPATH "$out/share/model-bench/src" \
      --add-flags "-m model_bench"

    runHook postInstall
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    MODEL_BENCH_DATA_DIR="$PWD" PYTHONPATH="$PWD/src" ${lib.getExe python3} -m model_bench --list-challenges >/dev/null
    runHook postCheck
  '';

  meta = {
    description = "Tier-aware LLM model assessor for Pi agent roles";
    mainProgram = "model-bench";
    platforms = lib.platforms.unix;
  };
}
