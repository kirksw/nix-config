{ inputs, pkgs, ... }:
{
  skills.mmx-cli = {
    description = "Use the official MiniMax CLI for MiniMax platform tasks.";
    src = pkgs.runCommand "mmx-cli-skill" { } ''
      mkdir -p "$out"
      awk '
        /^## Prerequisites$/ {
          print
          print ""
          print "`mmx` is installed and authenticated by Nix/SOPS. Do not install it, run `mmx auth login`, pass `--api-key`, or change the `api_key` config. Verify access with `mmx auth status`."
          skip = 1
          next
        }
        skip && /^---$/ { skip = 0 }
        /^## Configuration Precedence$/ { exit }
        !skip { print }
      ' ${inputs.minimax-cli-skill}/skill/SKILL.md > "$out/SKILL.md"
    '';
    version = "3615170a2e26ec6003c4550cd1324b55ec8ad677";
  };
}
