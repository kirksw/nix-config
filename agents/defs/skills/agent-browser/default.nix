{ pkgs, ... }:
{
  skills.agent-browser = {
    description = "Browser automation CLI for AI agents.";
    src = "${pkgs.agent-browser}/skills/agent-browser";
    version = pkgs.agent-browser.version;
  };
}
