{ inputs, ... }:
{
  skills.domain-modeling = {
    description = "Model a domain explicitly by identifying entities, relationships, invariants, and boundaries before implementation.";
    src = "${inputs.mattpocock-skills}/skills/engineering/domain-modeling";
    version = "1.0.0";
  };
}
