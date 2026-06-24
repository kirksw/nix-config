# Pi uses the ChatGPT/Codex OAuth-backed provider for personal OpenAI models.
# Keep this target-local so OpenCode continues to receive openai/... model IDs.
{ lib, ... }:
{
  imports = [ ../../defs/skills/codex-imagegen ];

  profiles.personal-default.tierMapping = {
    fast = lib.mkForce "openai-codex/gpt-5.4-mini";
    balanced = lib.mkForce "openai-codex/gpt-5.3-codex";
    powerful = lib.mkForce "openai-codex/gpt-5.5";
    reasoning = lib.mkForce "openai-codex/gpt-5.5";
  };
}
