{
  pkgs,
  inputs ? { },
  ...
}:
import ./pi-assets.nix { inherit pkgs inputs; }
