{
  self,
  lib,
  system,
}:

let
  piAnthropicCommunicationPolicyPackage = "${self}/agents/packages/pi-anthropic-communication-policy";
  piHerdrPackage = "${self}/agents/packages/pi-herdr";
  piTodoPackage = "${self}/agents/packages/pi-todo";
  piAgentJournalPackage = "${self}/agents/packages/pi-agent-journal";
  piMlflowTracerPackage = "${self.packages.${system}.pi-mlflow-tracer}";
  piLitellmProviderPackage = "${self}/agents/packages/pi-litellm-provider";
  bladebroPackage = "npm:bladebro@3.9.0";
  agenticOSPackage = "/Users/kisw/git/github.com/kirksw/agenticOS/main";

  piPackageRefs = [
    "npm:context-mode@1.0.169"
    {
      source = "npm:pi-cmux@0.1.16";
      autoload = false;
    }
    "npm:pi-cost@0.1.1"
    "npm:pi-dynamic-workflows@1.0.1"
    "npm:@llblab/pi-telegram@0.26.16"
    piAnthropicCommunicationPolicyPackage
    piHerdrPackage
    "npm:@tintinweb/pi-subagents@0.14.3"
    "npm:pi-observational-memory@3.0.3"
    "npm:pi-permission-system@0.8.0"
    "npm:pi-simplify@0.2.2"
    "npm:pi-verbosity-control@0.3.0"
    "npm:pi-web-access@0.13.0"
    "npm:@pi-plugins/fast-mode@0.1.8"
    "npm:@juicesharp/rpiv-ask-user-question@1.20.0"
    "npm:@juicesharp/rpiv-btw@1.20.0"
    piTodoPackage
    piAgentJournalPackage
    piMlflowTracerPackage
  ];
  packageSource = package: if builtins.isAttrs package then package.source else package;
  piLeanExcludedPackageRefs = [
    "npm:context-mode@1.0.169"
    piAgentJournalPackage
  ];
  piPersonalPackageRefs =
    builtins.filter (
      package: !(builtins.elem (packageSource package) piLeanExcludedPackageRefs)
    ) piPackageRefs
    ++ [ piLitellmProviderPackage ];
  piPersonalFullPackageRefs = piPackageRefs ++ [
    bladebroPackage
    piLitellmProviderPackage
  ];
  piWorkFullPackageRefs = piPackageRefs ++ [ agenticOSPackage ];
  piWorkPackageRefs = builtins.filter (
    package: !(builtins.elem (packageSource package) piLeanExcludedPackageRefs)
  ) piWorkFullPackageRefs;
  piFactoryPackageRefs = [
    piAnthropicCommunicationPolicyPackage
    piHerdrPackage
    piMlflowTracerPackage
    "npm:@tintinweb/pi-subagents@0.14.3"
    "npm:pi-permission-system@0.8.0"
    "npm:pi-verbosity-control@0.3.0"
    "npm:pi-web-access@0.13.0"
  ];
  piHomeFactoryPackageRefs = piFactoryPackageRefs ++ [ piLitellmProviderPackage ];
  piWorkFactoryPackageRefs = piFactoryPackageRefs ++ [ piAgentJournalPackage ];

  # Rose Pine (main) — matches the Herdr terminal theme (`theme.name = "rose-pine"`).
  # Palette: https://rosepinetheme.com
  piRosePineTheme = {
    "$schema" =
      "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
    name = "rose-pine";
    vars = {
      base = "#191724";
      surface = "#1f1d2e";
      overlay = "#26233a";
      low = "#21202e";
      med = "#403d52";
      high = "#524f67";
      muted = "#6e6a86";
      subtle = "#908caa";
      text = "#e0def4";
      love = "#eb6f92";
      gold = "#f6c177";
      rose = "#ebbcba";
      pine = "#31748f";
      foam = "#9ccfd8";
      iris = "#c4a7e7";
    };
    colors = {
      accent = "rose";
      border = "med";
      borderAccent = "iris";
      borderMuted = "low";
      success = "pine";
      error = "love";
      warning = "gold";
      muted = "subtle";
      dim = "muted";
      text = "";
      thinkingText = "foam";
      selectedBg = "med";
      scrollbarThumb = "high";
      userMessageBg = "surface";
      userMessageText = "";
      customMessageBg = "surface";
      customMessageText = "";
      customMessageLabel = "rose";
      toolPendingBg = "low";
      toolSuccessBg = "surface";
      toolErrorBg = "overlay";
      toolTitle = "rose";
      toolOutput = "";
      mdHeading = "gold";
      mdLink = "rose";
      mdLinkUrl = "iris";
      mdCode = "foam";
      mdCodeBlock = "";
      mdCodeBlockBorder = "high";
      mdQuote = "subtle";
      mdQuoteBorder = "iris";
      mdHr = "high";
      mdListBullet = "foam";
      toolDiffAdded = "foam";
      toolDiffRemoved = "love";
      toolDiffContext = "subtle";
      syntaxComment = "muted";
      syntaxKeyword = "iris";
      syntaxFunction = "rose";
      syntaxVariable = "gold";
      syntaxString = "foam";
      syntaxNumber = "love";
      syntaxType = "pine";
      syntaxOperator = "rose";
      syntaxPunctuation = "subtle";
      thinkingOff = "muted";
      thinkingMinimal = "subtle";
      thinkingLow = "foam";
      thinkingMedium = "iris";
      thinkingHigh = "gold";
      thinkingXhigh = "rose";
      thinkingMax = "love";
      bashMode = "gold";
    };
  };
  piThemeFile = builtins.toFile "rose-pine.json" (builtins.toJSON piRosePineTheme);
  piThemeSettings = {
    theme = "rose-pine";
    themes = [ piThemeFile ];
  };

  piPersonalModelDefaults = {
    defaultProvider = "zai";
    defaultModel = "glm-5.2";
    defaultThinkingLevel = "medium";
    enabledModels = [
      "litellm/openai/gpt-6-astra"
      "litellm/openai/gpt-5.5"
      "litellm/openai/gpt-5.6-sol"
      "litellm/openai/gpt-5.6-terra"
      "litellm/openai/gpt-5.6-luna"
      "litellm/minimax-m3"
      "litellm/glm-5.3"
      "litellm/glm-5.3-flash"
    ];
    subagents.disableBuiltins = true;
  };

  piPersonalSettings = builtins.toJSON (
    piPersonalModelDefaults
    // piThemeSettings
    // {
      packages = piPersonalPackageRefs;
    }
  );

  piPersonalFullSettings = builtins.toJSON (
    piPersonalModelDefaults
    // piThemeSettings
    // {
      packages = piPersonalFullPackageRefs;
    }
  );

  piMlxDsparkProvider = {
    baseUrl = "http://127.0.0.1:18080";
    api = "anthropic-messages";
    apiKey = "mlx-dspark";
    models = [
      {
        id = "Qwen3-8B-4bit";
        contextWindow = 131072;
        maxTokens = 8192;
      }
    ];
  };

  piPersonalModels = builtins.toJSON {
    providers.mlx-dspark = piMlxDsparkProvider;
  };

  piHomeFactorySettings = builtins.toJSON (
    {
      packages = piHomeFactoryPackageRefs;
      subagents.disableBuiltins = true;
    }
    // piThemeSettings
  );

  piWorkModelDefaults = {
    defaultProvider = "openai";
    defaultModel = "gpt-5.6-terra";
    defaultThinkingLevel = "medium";
    enabledModels = [
      "gpt-5.6-sol"
      "gpt-5.6-terra"
      "gpt-5.6-luna"
      "gpt-5.5"
      "gpt-5.4"
      "gpt-5.4-mini"
      "claude-opus-4-8"
      "claude-sonnet-4-6"
      "claude-opus-5"
      "claude-sonnet-5"
      "amazon-bedrock/eu.anthropic.claude-sonnet-5"
      "amazon-bedrock/eu.anthropic.claude-opus-5"
      "amazon-bedrock/eu.anthropic.claude-opus-4-8"
      "amazon-bedrock/eu.anthropic.claude-haiku-4-5-20251001-v1:0"
    ];
  };

  piWorkSettings = builtins.toJSON (
    piWorkModelDefaults
    // piThemeSettings
    // {
      packages = piWorkPackageRefs;
      subagents.disableBuiltins = true;
    }
  );

  piWorkFullSettings = builtins.toJSON (
    piWorkModelDefaults
    // piThemeSettings
    // {
      packages = piWorkFullPackageRefs;
      subagents.disableBuiltins = true;
    }
  );

  piWorkFactorySettings = builtins.toJSON (
    piWorkModelDefaults
    // piThemeSettings
    // {
      packages = piWorkFactoryPackageRefs;
      subagents.disableBuiltins = true;
    }
  );

  piWorkModels = builtins.toJSON {
    providers = {
      openai.baseUrl = "https://eu.api.openai.com/v1";
      mlx-dspark = piMlxDsparkProvider;
    };
  };

  piWorkFactoryModels = builtins.toJSON {
    providers.openai.baseUrl = "https://eu.api.openai.com/v1";
  };

  piPersonalMcpServers = {
    xcode = {
      command = "xcrun";
      args = [ "mcpbridge" ];
      lifecycle = "lazy";
    };
  };

  piWorkMcpServers = {
    "1password" = {
      command = "/Applications/1Password.app/Contents/MacOS/onepassword-mcp";
      lifecycle = "lazy";
    };
    granola = {
      url = "https://mcp.granola.ai/mcp";
      auth = "oauth";
      lifecycle = "lazy";
    };
    grafana = {
      url = "https://mcp-grafana.lunar.tech/mcp";
      lifecycle = "lazy";
    };
    linear = {
      url = "https://mcp.linear.app/mcp";
      auth = "oauth";
      lifecycle = "lazy";
    };
    lunar-skills = {
      command = "${self.packages.${system}.lunar-skills-mcp}/bin/lunar-skills-mcp";
      lifecycle = "lazy";
    };
    swe-pruner = {
      command = "${self.packages.${system}.swe-pruner-mcp}/bin/swe-pruner-mcp";
      lifecycle = "lazy";
    };
    hubble-mcp = {
      url = "https://hubble-mcp.prod.lunar.tech/mcp";
      auth = "oauth";
      lifecycle = "lazy";
    };
    sourcegraph = {
      url = "https://lunar.sourcegraph.com/.api/mcp";
      lifecycle = "lazy";
    };
    slack = {
      command = "npx";
      args = [
        "-y"
        "@jtalk22/slack-mcp"
      ];
      lifecycle = "lazy";
    };
  };

  piEmptyMcporter = builtins.toJSON {
    imports = [ ];
    mcpServers = { };
  };

  piPersonalMcporter = builtins.toJSON {
    imports = [ ];
    mcpServers = lib.mapAttrs (_: server: server // { lifecycle = "ephemeral"; }) piPersonalMcpServers;
  };

  piWorkMcporter = builtins.toJSON {
    imports = [ ];
    mcpServers = lib.mapAttrs (_: server: server // { lifecycle = "ephemeral"; }) piWorkMcpServers;
  };

  mkPiPersonalEnv = base: ''
    export PI_CACHE_RETENTION="long"
    export MLFLOW_TRACKING_URI="https://mlflow.cntd.io"
    export MLFLOW_EXPERIMENT_NAME="pi-home-traces"
    export MCPORTER_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents/pi/bases/${base}/settings/mcporter.json"
  '';

  piPersonalEnv = mkPiPersonalEnv "personal";
  piPersonalFullEnv = mkPiPersonalEnv "personal-full";

  mkPiWorkEnv =
    {
      base,
      agenticosToolMode,
    }:
    ''
      export PI_CACHE_RETENTION="long"
      export MLFLOW_TRACKING_URI="https://mlflow.cntd.io"
      export MLFLOW_EXPERIMENT_NAME="pi-work-traces"
      export AGENTICOS_INSTANCE="lunarOS"
      export AGENTICOS_TOOL_MODE="${agenticosToolMode}"
      export MCPORTER_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents/pi/bases/${base}/settings/mcporter.json"
      if [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
        export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
      fi
      export AWS_PROFILE="lw-employee-ai"
      export AWS_REGION="eu-west-1"
      export AWS_SDK_LOAD_CONFIG=1
    '';

  piWorkEnv = mkPiWorkEnv {
    base = "work";
    agenticosToolMode = "lazy";
  };
  piWorkFullEnv = mkPiWorkEnv {
    base = "work-full";
    agenticosToolMode = "eager";
  };

  piHomeFactoryEnv = ''
    export PI_CACHE_RETENTION="long"
    export MLFLOW_TRACKING_URI="https://mlflow.cntd.io"
    export MLFLOW_EXPERIMENT_NAME="pi-home-traces"
    export MCPORTER_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents/pi/bases/home-factory/settings/mcporter.json"
  '';

  piWorkFactoryEnv = ''
    export PI_CACHE_RETENTION="long"
    export MLFLOW_TRACKING_URI="https://mlflow.cntd.io"
    export MLFLOW_EXPERIMENT_NAME="pi-work-traces"
    export MCPORTER_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents/pi/bases/work-factory/settings/mcporter.json"
    if [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
      export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
    fi
    export AWS_PROFILE="lw-employee-ai"
    export AWS_REGION="eu-west-1"
    export AWS_SDK_LOAD_CONFIG=1
  '';

  piWorkAuth = builtins.toJSON {
    openai = {
      type = "api_key";
      key = "$OPENAI_API_KEY";
    };
    anthropic = {
      type = "oauth";
    };
  };

  codexPersonalSettings = ''
    approvals_reviewer = "guardian_subagent"
    suppress_unstable_features_warning = true
  '';

  codexWorkSettings = ''
    openai_base_url = "https://eu.api.openai.com/v1"
    approvals_reviewer = "guardian_subagent"
    suppress_unstable_features_warning = true
  '';
in
{
  inherit piPersonalPackageRefs piWorkAuth;

  targets = {
    codex = {
      personal = {
        "config.toml" = codexPersonalSettings;
      };
      work = {
        "config.toml" = codexWorkSettings;
      };
    };

    pi = {
      personal = {
        "settings.json" = piPersonalSettings;
        "models.json" = piPersonalModels;
        "mcporter.json" = piPersonalMcporter;
        "env" = piPersonalEnv;
      };
      personal-full = {
        "settings.json" = piPersonalFullSettings;
        "models.json" = piPersonalModels;
        "mcporter.json" = piPersonalMcporter;
        "env" = piPersonalFullEnv;
      };
      home-factory = {
        "settings.json" = piHomeFactorySettings;
        "mcporter.json" = piEmptyMcporter;
        "env" = piHomeFactoryEnv;
      };
      work = {
        "mcporter.json" = piWorkMcporter;
        "models.json" = piWorkModels;
        "settings.json" = piWorkSettings;
        "env" = piWorkEnv;
      };
      work-full = {
        "mcporter.json" = piWorkMcporter;
        "models.json" = piWorkModels;
        "settings.json" = piWorkFullSettings;
        "env" = piWorkFullEnv;
      };
      work-factory = {
        "auth.json" = piWorkAuth;
        "mcporter.json" = piEmptyMcporter;
        "models.json" = piWorkFactoryModels;
        "settings.json" = piWorkFactorySettings;
        "env" = piWorkFactoryEnv;
      };
    };
  };
}
