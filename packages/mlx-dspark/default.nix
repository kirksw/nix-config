{
  coreutils,
  curl,
  fetchPypi,
  jq,
  lib,
  nix,
  python3Packages,
  writeShellScript,
}:

let
  versions = lib.importJSON ./versions.json;
  downloadPython = python3Packages.python.withPackages (packages: [ packages.huggingface-hub ]);
  updatePython = python3Packages.python.withPackages (packages: [ packages.packaging ]);

  # nixpkgs builds MLX without Metal because the compiler is only shipped with Xcode.
  # Use the official wheels so local inference and custom Metal kernels are available.
  mlxMetalRuntime = python3Packages.buildPythonPackage {
    pname = "mlx-metal";
    inherit (versions.mlx) version;
    format = "wheel";

    src = fetchPypi {
      pname = "mlx_metal";
      inherit (versions.mlx) version;
      format = "wheel";
      python = "py3";
      dist = "py3";
      platform = "macosx_14_0_arm64";
      hash = versions.mlx.metalMacos14Arm64Hash;
    };

    doCheck = false;
  };

  mlxMetal = python3Packages.buildPythonPackage {
    pname = "mlx";
    inherit (versions.mlx) version;
    format = "wheel";

    src = fetchPypi {
      pname = "mlx";
      inherit (versions.mlx) version;
      format = "wheel";
      python = "cp314";
      dist = "cp314";
      abi = "cp314";
      platform = "macosx_14_0_arm64";
      hash = versions.mlx.cp314Macos14Arm64Hash;
    };

    dependencies = [ mlxMetalRuntime ];
    postInstall = ''
      cp -R \
        ${mlxMetalRuntime}/${python3Packages.python.sitePackages}/mlx/lib \
        "$out/${python3Packages.python.sitePackages}/mlx/lib"
    '';
    pythonImportsCheck = [ "mlx.core" ];
    doCheck = false;
  };

  mlxLm = python3Packages.mlx-lm.overridePythonAttrs (oldAttrs: {
    dependencies =
      map (
        dependency: if (dependency.pname or "") == "mlx" then mlxMetal else dependency
      ) oldAttrs.dependencies
      ++ [ python3Packages.sentencepiece ];
    doCheck = false;
  });

  mlxAudio = python3Packages.buildPythonPackage rec {
    pname = "mlx-audio";
    inherit (versions.mlxAudio) version;
    pyproject = true;

    src = fetchPypi {
      pname = "mlx_audio";
      inherit version;
      inherit (versions.mlxAudio) hash;
    };

    build-system = with python3Packages; [
      setuptools
      wheel
    ];
    dependencies = with python3Packages; [
      huggingface-hub
      miniaudio
      mlxMetal
      mlxLm
      numpy
      scipy
      sounddevice
      tqdm
      transformers
    ];

    pythonImportsCheck = [ "mlx_audio" ];
    doCheck = false;
  };

  mlxVlm = python3Packages.buildPythonPackage rec {
    pname = "mlx-vlm";
    inherit (versions.mlxVlm) version;
    pyproject = true;

    src = fetchPypi {
      pname = "mlx_vlm";
      inherit version;
      inherit (versions.mlxVlm) hash;
    };

    build-system = with python3Packages; [
      setuptools
      wheel
    ];
    dependencies = with python3Packages; [
      fastapi
      huggingface-hub
      llguidance
      miniaudio
      mlxMetal
      mlxLm
      mlxAudio
      numpy
      opencv-python
      pillow
      python-multipart
      requests
      starlette
      tqdm
      transformers
      uvicorn
    ];

    pythonImportsCheck = [ "mlx_vlm" ];
    doCheck = false;
  };
in
assert lib.assertMsg (
  python3Packages.python.pythonVersion == "3.14"
) "mlx-dspark official MLX wheel hashes require CPython 3.14";
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "mlx-dspark";
  inherit (versions.mlxDspark) version;
  pyproject = true;

  src = fetchPypi {
    pname = "mlx_dspark";
    inherit (finalAttrs) version;
    inherit (versions.mlxDspark) hash;
  };

  postPatch = ''
    substituteInPlace src/mlx_dspark/download.py \
      --replace-fail \
        '[sys.executable, "-c", child_src, repo]' \
        '["${downloadPython}/bin/python", "-c", child_src, repo]'
  '';

  build-system = [ python3Packages.hatchling ];
  dependencies = with python3Packages; [
    huggingface-hub
    mlxMetal
    mlxLm
    mlxVlm
    numpy
  ];

  pythonImportsCheck = [ "mlx_dspark" ];
  doCheck = false;

  passthru.updateScript = writeShellScript "update-mlx-dspark" ''
        set -euo pipefail

        versions_file="$repo_root/packages/mlx-dspark/versions.json"
        backup="$(${coreutils}/bin/mktemp)"
        ${coreutils}/bin/cp "$versions_file" "$backup"
        rollback() {
          ${coreutils}/bin/cp "$backup" "$versions_file"
          ${coreutils}/bin/rm -f "$backup"
        }
        trap rollback ERR INT TERM

        read -r latest_version latest_sha256 < <(
          ${updatePython}/bin/python - <<'PY'
    import json
    import urllib.request
    from packaging.version import Version

    with urllib.request.urlopen("https://pypi.org/pypi/mlx-dspark/json") as response:
        metadata = json.load(response)
    versions = [Version(value) for value in metadata["releases"]]
    stable = max(value for value in versions if not value.is_prerelease and not value.is_devrelease)
    release = metadata["releases"][str(stable)]
    sdist = next(
        item for item in release
        if item["packagetype"] == "sdist" and not item.get("yanked", False)
    )
    print(stable, sdist["digests"]["sha256"])
    PY
        )
        current_version="$(${jq}/bin/jq -r '.mlxDspark.version' "$versions_file")"
        if [[ "$latest_version" == "$current_version" ]]; then
          echo "mlx-dspark is already at latest stable $current_version"
          ${coreutils}/bin/rm -f "$backup"
          trap - ERR INT TERM
          exit 0
        fi

        latest_hash="$(${nix}/bin/nix hash convert --hash-algo sha256 --to sri "$latest_sha256")"
        tmp="$(${coreutils}/bin/mktemp "$versions_file.tmp.XXXXXX")"
        ${jq}/bin/jq \
          --arg version "$latest_version" \
          --arg hash "$latest_hash" \
          '.mlxDspark.version = $version | .mlxDspark.hash = $hash' \
          "$versions_file" >"$tmp"
        ${coreutils}/bin/chmod --reference="$versions_file" "$tmp"
        ${coreutils}/bin/mv "$tmp" "$versions_file"

        package="$(${nix}/bin/nix build "path:$repo_root#mlx-dspark" --no-link --print-out-paths)"
        "$package/bin/mlx-dspark" doctor
        CURL_BIN=${curl}/bin/curl JQ_BIN=${jq}/bin/jq \
          "$repo_root/scripts/check-mlx-dspark.sh" "$package/bin/mlx-dspark"

        ${coreutils}/bin/rm -f "$backup"
        trap - ERR INT TERM
        echo "Updated mlx-dspark to stable $latest_version; mlx-audio and mlx-vlm pins unchanged"
  '';

  meta = {
    description = "DSpark and DFlash speculative decoding for Apple Silicon via MLX";
    homepage = "https://github.com/ARahim3/mlx-dspark";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.kirksw ];
    mainProgram = "mlx-dspark";
    platforms = [ "aarch64-darwin" ];
  };
})
