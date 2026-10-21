args: {
  nix-mm1 = import ./nix-mm1.nix args;
  lunar = import ./lunar.nix (
    args
    // {
      inherit (args) ezgit;
    }
  );
}
