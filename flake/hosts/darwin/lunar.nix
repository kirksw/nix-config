{
  lunar-tools,
  yazi,
  llm-agents,
  nix-agents,
  neovim-nightly-overlay,
  ...
}:
{
  system = "aarch64-darwin";
  user = "kisw";
  hostModule = ../../../hosts/darwin/work;
  homeModule = ../../../hosts/darwin/work/home.nix;
  nixDirectory = "/Users/kisw/git/github.com/kirksw/nix-config";
  git = {
    fallback = "kirksw";
    profiles = {
      lunarway = {
        dirs = [
          "~/git/github.com/lunarway/**"
        ];
      };
      kirksw = {
        dirs = [
          "~/git/github.com/kirksw/**"
          "~/git/github.com/cntd-io/**"
          "~/git/github.com/kirksw/nix-config/**"
        ];
      };
    };
  };
  ssh = {
    keys = [
      "kirksw"
      "lunarway"
      "default"
      "k8s"
      "ry4a"
      "ry6b"
    ];
  };
  overlays = [
    lunar-tools.overlays.default
    yazi.overlays.default
    llm-agents.overlays.default
    nix-agents.overlays.default
    neovim-nightly-overlay.overlays.default

  ];
  enableHomebrew = true;
  enableLunar = true;
}
