# Pi profile definitions. Pi is the only configured target.
#
# A base is an environment boundary that owns shared runtime state: credentials,
# authentication, sessions, and the generated settings directory. A profile is a
# configuration overlay inside a base that selects skills and model tiers.
let
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
    personal-litellm-api-key = {
      credentialSource = "env";
      credentialRef = "PERSONAL_LITELLM_API_KEY";
      envVar = "LITELLM_API_KEY";
    };
    personal-litellm-cf-client-id = {
      credentialSource = "env";
      credentialRef = "PERSONAL_LITELLM_CF_ACCESS_CLIENT_ID";
      envVar = "LITELLM_CF_ACCESS_CLIENT_ID";
    };
    personal-litellm-cf-client-secret = {
      credentialSource = "env";
      credentialRef = "PERSONAL_LITELLM_CF_ACCESS_CLIENT_SECRET";
      envVar = "LITELLM_CF_ACCESS_CLIENT_SECRET";
    };
    work-openai-key = {
      credentialSource = "env";
      credentialRef = "LUNAR_OPENAI_API_KEY";
      envVar = "OPENAI_API_KEY";
    };
  };

  personalProviders = [
    "personal-zai-key"
    "personal-minimax-key"
    "personal-litellm-api-key"
    "personal-litellm-cf-client-id"
    "personal-litellm-cf-client-secret"
  ];
  workProviders = [ "work-openai-key" ];

  personalGit = {
    userName = "Kirk Sweeney";
    userEmail = "kirk@cntd.io";
    signingKey = "/Users/kisw/.config/sops-nix/secrets/ssh/kirksw/private";
  };
  workGit = {
    userName = "Kirk Sweeney";
    userEmail = "kisw@lunar.app";
    signingKey = "/Users/kisw/.config/sops-nix/secrets/ssh/lunarway/private";
  };

  mkBase = providerNames: git: {
    providers = providerNames;
    inherit git;
  };

  personalSkills = [
    "agent-browser"
    "codex-imagegen"
    "domain-modeling"
    "google-hotels"
    "home-mcp"
    "land"
    "lavish"
    "nix-config"
    "session-heuristics"
    "skill-creator"
  ];
  workSkills = [
    "1password"
    "grafana"
    "granola"
    "hubble-mcp"
    "land"
    "lavish"
    "linear"
    "lunar-skills"
    "nix-config"
    "slack"
    "sourcegraph"
    "work-mcp"
  ];
  personalBrowserSkills = [
    "affine"
    "agent-browser"
    "google-hotels"
    "home-mcp"
    "nix-config"
  ];
  workBrowserSkills = [
    "agent-browser"
    "google-hotels"
    "nix-config"
  ];

  personalTierMapping = {
    S = [ "litellm/openai/gpt-6-astra" ];
    A = [
      "litellm/openai/gpt-6-sol"
      "litellm/glm-5.3"
    ];
    B = [
      "litellm/glm-5.3-flash"
      "litellm/openai/gpt-6-luna"
    ];
    C = [
      "litellm/deepseek-v4-pro"
      "litellm/deepseek-flash"
    ];
  };
  workTierMapping = {
    S = [
      "openai/gpt-6-astra"
      "amazon-bedrock/eu.anthropic.claude-opus-5-5"
    ];
    A = [ "openai/gpt-6-sol" ];
    B = [ "openai/gpt-6-luna" ];
    C = [ "openai/gpt-6-luna" ];
  };
in
{
  inherit providers;

  bases = {
    personal = mkBase personalProviders personalGit;
    personal-default = mkBase personalProviders personalGit;
    personal-browser = mkBase personalProviders personalGit;
    work = mkBase workProviders workGit;
    work-default = mkBase workProviders workGit;
    work-browser = mkBase workProviders workGit;
  };

  profiles = {
    personal-default = {
      base = "personal-default";
      skills = personalSkills;
      tierMapping = personalTierMapping;
    };
    personal-fallback = {
      base = "personal";
      skills = personalSkills;
      tierMapping = personalTierMapping;
    };
    personal-browser = {
      base = "personal-browser";
      skills = personalBrowserSkills;
      tierMapping = personalTierMapping;
    };
    work-default = {
      base = "work-default";
      skills = workSkills;
      tierMapping = workTierMapping;
    };
    work-fallback = {
      base = "work";
      skills = workSkills;
      tierMapping = workTierMapping;
    };
    work-browser = {
      base = "work-browser";
      skills = workBrowserSkills;
      tierMapping = workTierMapping;
    };
  };
}
