{
  lib,
  fetchFromGitHub,
  python3Packages,
}:

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
    curl-cffi
    httpx
    plotext
    pydantic
    python-dotenv
    ratelimit
    tenacity
    typer
  ];

  pythonImportsCheck = [ "fli" ];

  meta = {
    description = "Flight search CLI using Google Flights data";
    homepage = "https://github.com/punitarani/fli";
    license = lib.licenses.mit;
    mainProgram = "fli";
    platforms = lib.platforms.unix;
  };
}
