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
        "~/git/github.com/kirksw/lunarOS"
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
      skills = [ ]; # empty = all
      mcpServers = [
        "swe-pruner"
      ];
      tierMapping = {
        S = [ "openai-codex/gpt-5.6-sol" ];
        A = [
          "openai-codex/gpt-5.6-terra"
          "openai-codex/gpt-5.5"
          "zai/glm-5.2"
        ];
        B = [
          "openai-codex/gpt-5.6-luna"
          "openai-codex/gpt-5.4"
        ];
        C = [
          "openai-codex/gpt-5.4-mini"
          "minimax/minimax-m3"
        ];
        D = [
          "openai-codex/gpt-5.3-codex-spark"
          "minimax/minimax-m2.7-highspeed"
          "zai/glm-5-turbo"
        ];
        E = [ "openai-codex/gpt-5.4-nano" ];
      };
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
        "scout"
        "bottleneck"
        "chaos-demon"
        "code-red"
        "scribe"
      ];
      skills = [
        "grill-me"
        "grill-with-docs"
        "grilling"
        "domain-modeling"
        "lavish"
        "homelab"
        "nix-agents"
        "parallel-reviews"
        "session-heuristics"
        "system-context"
        "what-if"
        "plan-x"
        "writing-great-skills"
      ];
      mcpServers = [
        "1password"
        "lunar-skills"
        "swe-pruner"
        "granola"
        "grafana"
        "google-drive"
        "linear"
        "sourcegraph"
      ];
      tierMapping = {
        S = [
          "openai/gpt-5.6-sol"
          "anthropic/claude-fable-5"
        ];
        A = [
          "openai/gpt-5.6-terra"
          "anthropic/claude-opus-4-8"
          "openai/gpt-5.5"
        ];
        B = [
          "openai/gpt-5.6-luna"
          "anthropic/claude-sonnet-4-6"
          "openai/gpt-5.4"
        ];
        C = [ "openai/gpt-5.4-mini" ];
        D = [ "openai/gpt-5.3-codex-spark" ];
        E = [
          "anthropic/claude-haiku-4-5-20251001"
          "openai/gpt-5.4-nano"
        ];
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
