# Pi-only profile layout; other targets retain their shared presets.
{ lib, ... }:
let
  shared = import ../../presets/profiles.nix { };
  fallback =
    scope:
    shared.profiles."${scope}-default"
    // {
      skills =
        shared.profiles."${scope}-default".skills ++ lib.optional (scope == "personal") "codex-imagegen";
    };
  base = scope: kind: {
    inherit (shared.bases.${scope}) providers git;
    pathPrefixes = lib.optionals (kind == "default") shared.bases.${scope}.pathPrefixes;
    defaultProfile = "${scope}-${kind}";
  };
  profile =
    scope: kind:
    (fallback scope)
    // {
      base = "${scope}-${kind}";
      pathPrefixes = [ ];
    };
  browser =
    scope:
    (profile scope "browser")
    // {
      skills = [
        "agent-browser"
        "google-hotels"
        "system-context"
      ];
      permissions = {
        edit = null;
        bash = null;
        task = null;
        webfetch = "allow";
      };
    };
in
{
  bases = {
    personal = {
      pathPrefixes = lib.mkForce [ ];
      defaultProfile = lib.mkForce "personal-fallback";
    };
    work = {
      pathPrefixes = lib.mkForce [ ];
      defaultProfile = lib.mkForce "work-fallback";
    };
    personal-default = base "personal" "default";
    work-default = base "work" "default";
    personal-browser = base "personal" "browser";
    work-browser = base "work" "browser";
  };
  profiles = {
    personal-fallback = fallback "personal";
    work-fallback = fallback "work";
    personal-default = lib.mkForce (profile "personal" "default");
    work-default = lib.mkForce (profile "work" "default");
    personal-browser = browser "personal";
    work-browser = browser "work";
  };
}
