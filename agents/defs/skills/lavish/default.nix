{ inputs, ... }:
{
  skills.lavish = {
    description = "Turn complex or visual agent responses into rich, reviewable HTML artifacts the user can annotate and send feedback on, using the lavish-axi CLI.";
    src = "${inputs.lavish-axi}/skills/lavish";
    version = "0.1.43";
  };
}
