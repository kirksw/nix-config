{
  inputs,
  stdenv,
}:

# Passthrough of the upstream land package from the git-land flake input so the
# CLI stays on PATH for shells and every Pi profile session.
let
  system = stdenv.hostPlatform.system;
in
inputs.git-land.packages.${system}.land
