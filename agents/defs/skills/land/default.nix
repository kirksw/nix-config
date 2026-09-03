{ inputs, ... }:
{
  skills.land = {
    description = "Land completed branch changes through the land CLI. Use when work is ready to submit, when a pull request's CI fails, or when asked to land, submit, publish, or verify changes. Drives synchronize -> validate -> publish -> verify by rerunning `land --json` and following its blockedOn hints.";
    src = "${inputs.git-land}/.agents/skills/land";
    version = "0.1";
  };
}
