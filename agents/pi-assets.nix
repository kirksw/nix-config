# Local Pi profile asset generator.
#
# Replaces the upstream `nix-agents` engine for the only target this repository
# configures. It packages, per profile: skills, AGENTS.md with the generated
# model-tier manifest, hook-manifest, skill-versions.json, Pi extensions, and
# Pi prompts.
{
  pkgs,
  inputs ? { },
}:
let
  lib = pkgs.lib;
  presets = import ./pi-profiles.nix;
  inherit (presets) bases providers profiles;

  skillFiles = [
    ./defs/skills/1password
    ./defs/skills/activities-search
    ./defs/skills/affine
    ./defs/skills/agent-browser
    ./defs/skills/codex-imagegen
    ./defs/skills/domain-modeling
    ./defs/skills/fli
    ./defs/skills/google-flights
    ./defs/skills/google-hotels
    ./defs/skills/grafana
    ./defs/skills/granola
    ./defs/skills/grill-me
    ./defs/skills/grill-with-docs
    ./defs/skills/grilling
    ./defs/skills/home-mcp
    ./defs/skills/homelab
    ./defs/skills/hotel-search
    ./defs/skills/hubble-mcp
    ./defs/skills/land
    ./defs/skills/last30days
    ./defs/skills/lavish
    ./defs/skills/linear
    ./defs/skills/lunar-skills
    ./defs/skills/microvm-agent
    ./defs/skills/nix-config
    ./defs/skills/parallel-reviews
    ./defs/skills/plan-x
    ./defs/skills/session-heuristics
    ./defs/skills/session-resume.nix
    ./defs/skills/skill-creator
    ./defs/skills/slack
    ./defs/skills/sourcegraph
    ./defs/skills/travel-search
    ./defs/skills/what-if
    ./defs/skills/work-mcp
    ./defs/skills/writing-great-skills
    ./defs/skills/xcode
    ./defs/skills/yeet
  ];

  evalSkillFile =
    file:
    let
      value = import file;
    in
    if builtins.isFunction value then value { inherit pkgs inputs lib; } else value;

  skills = builtins.foldl' (acc: file: acc // (evalSkillFile file).skills or { }) { } skillFiles;

  selectSkills =
    names: if names == [ ] then skills else lib.filterAttrs (name: _: builtins.elem name names) skills;

  yamlEscape =
    string:
    lib.replaceStrings
      [
        "\\"
        "\""
        "\n"
        "\r"
      ]
      [
        "\\\\"
        "\\\""
        "\\n"
        ""
      ]
      string;

  mkSkillContent =
    name: skill:
    let
      frontmatter = ''
        ---
        name: "${yamlEscape name}"
        description: "${yamlEscape (skill.description or "")}"
        ---
      '';
    in
    if (skill.content or "") == "" then frontmatter else frontmatter + "\n" + skill.content;

  writeSkill =
    name: skill:
    if (skill.src or null) != null then
      ''
        mkdir -p "$out/skills/${name}"
        cp -r ${skill.src}/. "$out/skills/${name}/"
        chmod -R u+w "$out/skills/${name}"
      ''
    else
      ''
        mkdir -p "$out/skills/${name}"
        cp ${builtins.toFile "skill-${name}.md" (mkSkillContent name skill)} "$out/skills/${name}/SKILL.md"
      '';

  mkSkillVersions =
    selected:
    pkgs.writeText "skill-versions.json" (
      builtins.toJSON (lib.mapAttrs (_: skill: skill.version or "unversioned") selected)
    );

  hookManifest = builtins.toFile "hook-manifest" "";

  tierOrder = [
    "S"
    "A"
    "B"
    "C"
    "D"
    "E"
  ];

  mkTierManifest =
    tierMapping:
    let
      tiers = builtins.filter (tier: tierMapping ? ${tier}) tierOrder;
      rows = map (
        tier:
        let
          chain = tierMapping.${tier};
        in
        "| ${tier} | ${builtins.head chain} | ${lib.concatStringsSep " → " (builtins.tail chain)} |"
      ) tiers;
    in
    ''
      <!-- nix-config:tier-manifest:start -->
      ## Model Tiers (generated)

      Tier keys resolve to ordered model chains per-profile from `tierMapping` in
      `agents/pi-profiles.nix`.

      ### Tier → model chain

      | Tier | Default model | Ordered fallbacks |
      |------|---------------|-------------------|
      ${lib.concatStringsSep "\n" rows}

      ### Using this

      - **Sparring**: put two agents on the same tier so they run peer-strength models.
      - **Backup failover**: use the next model in the chain when the default is unavailable.
      - **Peer review**: select a reviewer tier that is at least as strong as the producer.

      > Model tiers live in `agents/pi-profiles.nix`; edit there, never in generated files.
      <!-- nix-config:tier-manifest:end -->
    '';

  mkAgentsMd =
    profile:
    pkgs.writeText "AGENTS.md" (
      (builtins.readFile ./AGENTS.md) + "\n\n" + mkTierManifest profile.tierMapping
    );

  mkProfileAssets =
    name:
    let
      profile = profiles.${name};
      selected = selectSkills profile.skills;
    in
    pkgs.runCommand "pi-profile-${name}" { } ''
      mkdir -p "$out/agents" "$out/skills" "$out/extensions" "$out/prompts"
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList writeSkill selected)}
      cp ${mkSkillVersions selected} "$out/skill-versions.json"
      cp ${hookManifest} "$out/hook-manifest"
      cp ${mkAgentsMd profile} "$out/AGENTS.md"
      cp -r ${./targets/pi/extensions}/. "$out/extensions/"
      cp -r ${./targets/pi/prompts}/. "$out/prompts/"
    '';

  profileMeta = lib.mapAttrs (
    name: profile:
    let
      base = bases.${profile.base};
    in
    {
      storePath = mkProfileAssets name;
      inherit (profile) base;
      providers = map (provider: providers.${provider}) base.providers;
      inherit (base) git;
    }
  ) profiles;
in
{
  inherit
    providers
    bases
    profiles
    skills
    profileMeta
    ;
}
