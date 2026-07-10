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

    work-factory = {
      base = "work-factory";
      pathPrefixes = [ ];
      agents = [ ];
      skills = [ ];
      mcpServers = [ ];
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
  };
}
