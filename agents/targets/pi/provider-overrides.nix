# Pi uses the ChatGPT/Codex OAuth-backed provider for personal OpenAI models.
# Keep this target-local so OpenCode continues to receive openai/... model IDs.
# The codex-imagegen bridge is also pi-only: the skill shells out to `codex
# exec`, so it is appended to personal-default here rather than in the shared
# profiles preset (other targets would fail profile reference validation).
{ ... }:
{
  imports = [ ../../defs/skills/codex-imagegen ];

  profiles.personal-default.skills = [ "codex-imagegen" ];
}
