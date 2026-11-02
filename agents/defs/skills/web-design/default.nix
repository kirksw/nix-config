{ inputs, ... }:
let
  emilSkills = builtins.readDir "${inputs.emilkowalski-skills}/skills";
  emilNames = builtins.filter (name: emilSkills.${name} == "directory") (
    builtins.attrNames emilSkills
  );
  mkEmilSkill = name: {
    name = name;
    value = {
      description = "Use Emil Kowalski's ${name} design and engineering guidance when the task matches its SKILL.md.";
      src = "${inputs.emilkowalski-skills}/skills/${name}";
      version = "f1090bec";
    };
  };
in
{
  skills = builtins.listToAttrs (map mkEmilSkill emilNames) // {
    impeccable = {
      description = "Design, critique, and polish frontend interfaces with Impeccable's design workflow.";
      src = "${inputs.impeccable-skill}/.pi/skills/impeccable";
      version = "4.8.0";
    };
    design-taste-frontend = {
      description = "Art direct and verify public-facing websites and app screens using the Taste skill.";
      src = "${inputs.taste-skill}/skills/taste-skill";
      version = "12af471f";
    };
  };
}
