# Pi uses the ChatGPT/Codex OAuth-backed provider for personal OpenAI models.
# Keep this target-local so OpenCode continues to receive openai/... model IDs.
{ ... }:
{
  imports = [ ../../defs/skills/codex-imagegen ];
}
