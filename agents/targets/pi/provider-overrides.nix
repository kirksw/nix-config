# Personal Pi agent tiers use LiteLLM in experimental-profiles.nix.
# Keep the separate Codex CLI image-generation bridge available.
# The codex-imagegen bridge is also pi-only: the skill shells out to `codex
# exec`, so it is appended to personal-default here rather than in the shared
# profiles preset (other targets would fail profile reference validation).
{ ... }:
{
  imports = [ ../../defs/skills/codex-imagegen ];

  profiles.personal-default.skills = [ "codex-imagegen" ];
}
