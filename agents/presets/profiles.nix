# ADR-0001 base/profile preset.
# Each base represents an environment boundary (work/personal) that owns
# shared runtime state (credentials, auth, sessions). Profiles are
# configuration overlays within a base.

_: {
  providers = {
    personal-zai-key = {
      credentialSource = "env";
      credentialRef = "PERSONAL_ZAI_API_KEY";
      envVar = "ZAI_API_KEY";
    };
    personal-minimax-key = {
      credentialSource = "env";
      credentialRef = "PERSONAL_MINIMAX_API_KEY";
      envVar = "MINIMAX_API_KEY";
    };
    work-openai-key = {
      credentialSource = "env";
      credentialRef = "LUNAR_OPENAI_API_KEY";
      envVar = "OPENAI_API_KEY";
    };
  };

  bases = {
    # personal — personal projects, full agent access, own credentials
    personal = {
      pathPrefixes = [
        "~/src/"
        "~/projects/"
      ];
      providers = [
        "personal-zai-key"
        "personal-minimax-key"
      ];
      defaultProfile = "default";
      git = {
        userName = "Kirk Sweeney";
        userEmail = "kirk@cntd.io";
        signingKey = "/Users/kisw/.config/sops-nix/secrets/ssh/kirksw/private";
        gpgFormat = "ssh";
      };
    };

    # work — work projects, restricted agent set, shared work credentials
    work = {
      pathPrefixes = [
        "~/git/github.com/lunarway/"
        "~/projects/lunar/"
      ];
      providers = [ "work-openai-key" ];
      defaultProfile = "default";
      git = {
        userName = "Kirk Sweeney";
        userEmail = "kisw@lunar.app";
        signingKey = "/Users/kisw/.config/sops-nix/secrets/ssh/lunarway/private";
        gpgFormat = "ssh";
      };
    };
  };

  profiles = {
    # --- personal profiles ---

    personal-default = {
      base = "personal";
      pathPrefixes = [ ];
      agents = [ ]; # empty = all
      skills = [
        "add-module"
        "grill-me"
        "nix-agents"
        "parallel-reviews"
        "secrets-management"
        "session-resume"
        "skill-creator"
      ];
      mcpServers = [ ]; # empty = all
      tierMapping = { };
    };

    # --- work profiles ---

    # work/stable: conservative model tiers, stricter permissions
    work-default = {
      base = "work";
      pathPrefixes = [ ];
      agents = [
        "10xBEAST"
        "the-architect"
        "code-monkey"
        "explore"
        "bottleneck"
        "chaos-demon"
        "code-red"
        "scribe"
      ];
      skills = [
        "grill-me"
        "nix-agents"
        "parallel-reviews"
        "system-context"
      ];
      mcpServers = [ ];
      tierMapping = {
        fast = "openai/gpt-5.4-mini";
        balanced = "anthropic/claude-sonnet-4-6";
        powerful = "openai/gpt-5.5";
        reasoning = "anthropic/claude-opus-4-8";
      };
      permissions = {
        edit = null;
        bash = null;
        task = null;
        webfetch = "deny";
      };
    };

    # work/team: same work auth, team-optimized delegation
    # (future: add team-specific agents/skills here)
  };
}
