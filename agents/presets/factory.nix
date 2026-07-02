# Minimal Pi profiles used by lifeOS agenticOS factory wrappers.
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
    home-factory = {
      pathPrefixes = [ ];
      providers = [
        "personal-zai-key"
        "personal-minimax-key"
      ];
      defaultProfile = "home-factory";
      git = {
        userName = "Kirk Sweeney";
        userEmail = "kirk@cntd.io";
        signingKey = "/Users/kisw/.config/sops-nix/secrets/ssh/kirksw/private";
        gpgFormat = "ssh";
      };
    };

    work-factory = {
      pathPrefixes = [ ];
      providers = [ "work-openai-key" ];
      defaultProfile = "work-factory";
      git = {
        userName = "Kirk Sweeney";
        userEmail = "kisw@lunar.app";
        signingKey = "/Users/kisw/.config/sops-nix/secrets/ssh/lunarway/private";
        gpgFormat = "ssh";
      };
    };
  };

  profiles = {
    home-factory = {
      base = "home-factory";
      pathPrefixes = [ ];
      agents = [ ];
      skills = [ ];
      mcpServers = [ ];
      tierMapping = {
        ultrafast = "minimax/minimax-m2.7-highspeed";
        fast = "openai-codex/gpt-5.4-mini";
        balanced = "openai-codex/gpt-5.3-codex";
        powerful = "openai-codex/gpt-5.5";
        reasoning = "openai-codex/gpt-5.5";
      };
    };

    work-factory = {
      base = "work-factory";
      pathPrefixes = [ ];
      agents = [ ];
      skills = [ ];
      mcpServers = [ ];
      tierMapping = {
        ultrafast = "openai/gpt-5.3-codex-spark";
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
  };
}
