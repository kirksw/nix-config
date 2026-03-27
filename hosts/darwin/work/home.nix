{
  self,
  user,
  pkgs,
  ...
}:

{
  home = {
    stateVersion = "24.05";
    packages = with pkgs; [
      fastfetch
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
    ];
    sessionVariables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "";
    };
  };

  programs.home-manager.enable = true;

  # enabled custom modules
  # security
  homeModules.sops.enable = true;
  # dev tooling
  homeModules.appearanceSync.enable = true;
  homeModules.zsh.enable = true;
  homeModules.developer.enable = true;
  homeModules.colima.enable = true;
  homeModules.devops.enable = true;
  # company
  homeModules.lunar.enable = true;
  # editors
  homeModules.neovim.enable = true;
  # multiplexer
  homeModules.tmux.enable = true;
  homeModules.zellij.enable = false;
  # terminal
  homeModules.ghostty.enable = false;
  homeModules.wezterm.enable = true;
  homeModules.qemu.enable = true;
  # ai tooling
  homeModules.claudeCode.enable = true;
  homeModules.aiDev.enable = true;
  homeModules.treekanga.enable = false;
  homeModules.opencode.enable = true;
  homeModules.piCodingAgent.enable = true;
  homeModules.codex.enable = true;
  homeModules.swePrunerMcp.enable = true;
  homeModules.cursor.enable = true;
  # misc
  homeModules.youtube.enable = true;

  # disabled custom modules
  homeModules.communication.enable = false;
  homeModules.homerow.enable = false;
  homeModules.gcloud.enable = false;
  homeModules.vscode.enable = false;
}
