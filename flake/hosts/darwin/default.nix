args:
{
  lunar = import ./lunar.nix (args // {
    inherit (args) nix-agents;
  });
}
