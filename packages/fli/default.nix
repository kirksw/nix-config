{
  cctools,
  curl,
  curl-impersonate,
  lib,
  fetchFromGitHub,
  gnused,
  nix-update,
  python3Packages,
  stdenv,
  writeShellScript,
}:

let
  curlCffi = python3Packages.curl-cffi.overrideAttrs (old: {
    # Keep the import check, but do not make Fli depend on curl-cffi's
    # upstream protocol suite, which currently fails against nixpkgs' Darwin
    # curl-impersonate build after the binding loads successfully.
    dontUsePytestCheck = stdenv.hostPlatform.isDarwin;

    postInstall =
      (old.postInstall or "")
      + lib.optionalString stdenv.hostPlatform.isDarwin ''
        ${cctools}/bin/install_name_tool \
          -add_rpath ${curl-impersonate}/lib \
          "$out/${python3Packages.python.sitePackages}/curl_cffi/_wrapper.abi3.so"
      '';
  });
in
python3Packages.buildPythonApplication rec {
  pname = "fli";
  version = "0.10.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "punitarani";
    repo = "fli";
    rev = "121d34fea056dc513258958c4262cb5a4cc033c1";
    hash = "sha256-SJk4fGqL3xnU505TI+3oHd1+YqlvoVKcN3W+8jKqGmI=";
  };

  build-system = [ python3Packages.hatchling ];
  dependencies = with python3Packages; [
    babel
    curlCffi
    httpx
    plotext
    pydantic
    python-dotenv
    ratelimit
    tenacity
    typer
  ];

  pythonImportsCheck = [ "fli" ];

  passthru.updateScript = writeShellScript "update-fli" ''
    set -euo pipefail
    package_file="$repo_root/packages/fli/default.nix"
    rev="$(${lib.getExe curl} -fsSL https://api.github.com/repos/punitarani/fli/commits/main | ${lib.getExe gnused} -n -E 's/^[[:space:]]*"sha": "([^"]+)",/\1/p' | ${lib.getExe gnused} -n '1p')"
    version="$(${lib.getExe curl} -fsSL https://raw.githubusercontent.com/punitarani/fli/main/pyproject.toml | ${lib.getExe gnused} -n -E 's/^version = "([^"]+)"/\1/p')"
    test -n "$rev"
    test -n "$version"
    ${lib.getExe gnused} -i -E "s|rev = \"[^\"]+\";|rev = \"$rev\";|" "$package_file"
    ${lib.getExe nix-update} --flake --version="$version" fli
    echo "Updated fli to version $version ($rev)"
  '';

  meta = {
    description = "Flight search CLI using Google Flights data";
    homepage = "https://github.com/punitarani/fli";
    license = lib.licenses.mit;
    mainProgram = "fli";
    platforms = lib.platforms.unix;
  };
}
