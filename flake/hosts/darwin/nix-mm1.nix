_: {
  system = "aarch64-darwin";
  user = "agent";
  hostModule = ../../../hosts/darwin/headless;
  homeModule = ../../../hosts/darwin/headless/home.nix;
  enableHomebrew = false;
  enableLunar = false;
}
