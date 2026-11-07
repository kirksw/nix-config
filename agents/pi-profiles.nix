# Pi profile definitions. Pi is the only configured target.
#
# A base is an environment boundary that owns shared runtime state: credentials,
# authentication, sessions, and the generated settings directory. A profile is a
# configuration overlay inside a base that selects skills and model tiers.
let
  providers = {
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
  };

  personalProviders = [
    "personal-minimax-key"
    "personal-litellm-api-key"
    "personal-litellm-cf-client-id"
    "personal-litellm-cf-client-secret"
  ];
  workProviders = [ ];

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
    "semantic-svg-diagrams"
    "session-heuristics"
    "skill-creator"
  ];
  workSkills = [
    "1password"
    "doc-coauthoring"
    "excalidraw-diagram"
    "grafana"
    "granola"
    "hubble-mcp"
    "lavish"
    "linear"
    "lunar-skills"
    "nix-config"
    "semantic-svg-diagrams"
    "slack"
    "sourcegraph"
  ];
  workNativeMcpSkills = [
    "doc-coauthoring"
    "excalidraw-diagram"
    "lavish"
    "nix-config"
    "semantic-svg-diagrams"
    "work-mcp"
  ];
  personalBrowserSkills = [
    "affine"
    "agent-browser"
    "google-hotels"
    "home-mcp"
    "nix-config"
    "semantic-svg-diagrams"
  ];
  workBrowserSkills = [
    "agent-browser"
    "doc-coauthoring"
    "excalidraw-diagram"
    "google-hotels"
    "nix-config"
    "semantic-svg-diagrams"
  ];
  webDesignSkills = [
    "animate-expo"
    "animate"
    "animation-performance"
    "animation-vocabulary"
    "apple-design"
    "ask-sonner"
    "break-ui"
    "emil-design-eng"
    "find-animation-opportunities"
    "improve-animations"
    "mobile-native"
    "pick-ui-library"
    "prototype"
    "remove-animations"
    "review-animations"
    "write-swift"
    "impeccable"
    "design-taste-frontend"
  ];
  personalWebSkills = personalSkills ++ webDesignSkills;
  workWebSkills = workNativeMcpSkills ++ [ "agent-browser" ] ++ webDesignSkills;

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
    S = [ "lunar/gpt-6-astra" ];
    A = [ "lunar/gpt-6.1-sol" ];
    B = [ "lunar/gpt-6-luna" ];
    C = [ "lunar/gpt-6-luna" ];
  };
in
{
  inherit providers;

  bases = {
    personal = mkBase personalProviders personalGit;
    personal-default = mkBase personalProviders personalGit;
    personal-browser = mkBase personalProviders personalGit;
    personal-web = mkBase personalProviders personalGit;
    work = mkBase workProviders workGit;
    work-default = mkBase workProviders workGit;
    work-browser = mkBase workProviders workGit;
    work-web = mkBase workProviders workGit;
  };

  profiles = {
    personal-default = {
      base = "personal-default";
      skills = personalSkills;
      tierMapping = personalTierMapping;
      excludeExtensions = [ "work-mcp-approval" ];
    };
    personal-fallback = {
      base = "personal";
      skills = personalSkills;
      tierMapping = personalTierMapping;
      excludeExtensions = [ "work-mcp-approval" ];
    };
    personal-browser = {
      base = "personal-browser";
      skills = personalBrowserSkills;
      tierMapping = personalTierMapping;
      excludeExtensions = [ "work-mcp-approval" ];
    };
    personal-web = {
      base = "personal-web";
      skills = personalWebSkills;
      tierMapping = personalTierMapping;
      excludeExtensions = [ "work-mcp-approval" ];
    };
    work-default = {
      base = "work-default";
      skills = workNativeMcpSkills;
      tierMapping = workTierMapping;
      excludeExtensions = [ "minimal-mode" ];
    };
    work-fallback = {
      base = "work";
      skills = workSkills;
      tierMapping = workTierMapping;
      excludeExtensions = [
        "minimal-mode"
        "work-mcp-approval"
      ];
    };
    work-browser = {
      base = "work-browser";
      skills = workBrowserSkills;
      tierMapping = workTierMapping;
      excludeExtensions = [
        "minimal-mode"
        "work-mcp-approval"
      ];
    };
    work-web = {
      base = "work-web";
      skills = workWebSkills;
      tierMapping = workTierMapping;
      excludeExtensions = [ "minimal-mode" ];
    };
  };
}
