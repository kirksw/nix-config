args: {
  lunar = import ./lunar.nix (
    args
    // {
      inherit (args) ezgit nix-agents;
    }
  );
}
