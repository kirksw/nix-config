{
  self,
  lib,
  system,
}:

let
  piHerdrPackage = "${self}/agents/packages/pi-herdr";
  piTodoPackage = "${self}/agents/packages/pi-todo";
  piAgentJournalPackage = "${self}/agents/packages/pi-agent-journal";
  piLitellmProviderPackage = "${self}/agents/packages/pi-litellm-provider";
  agenticOSPackage = "/Users/kisw/git/github.com/kirksw/agenticOS/main";
  piNpmCommand = "${self.packages.${system}.pi-npm}/bin/pi-npm";

  # Lunarway Pi packages (github.com/lunarway/pi-packages) are published to
  # GitHub Packages. `piNpmCommand` routes their installs through the lunarctl
  # npm wrapper, which supplies the registry token from gh.
  piLunarPackageRefs = [
    "npm:@lunarway/pi-lunar-quiet-tools@0.1.0"
    "npm:@lunarway/pi-lunar-litellm@0.2.1"
    "npm:@lunarway/pi-lunar-statusline@0.7.0"
  ];

  piPackageRefs = [
    "npm:context-mode@1.0.169"
    "npm:pi-cost@0.1.1"
    piHerdrPackage
    "npm:@tintinweb/pi-subagents@0.14.3"
    "npm:pi-observational-memory@3.0.3"
    "npm:pi-verbosity-control@0.3.0"
    "npm:pi-web-access@0.13.0"
    "npm:@juicesharp/rpiv-btw@1.20.0"
    piTodoPackage
    piAgentJournalPackage
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
  piWorkPackageRefs = builtins.filter (
    package: !(builtins.elem (packageSource package) piLeanExcludedPackageRefs)
  ) (piPackageRefs ++ piLunarPackageRefs ++ [ agenticOSPackage ]);
  # Minimal profile package set: web access, output verbosity, and LiteLLM models.
  # The fallback profiles use this set and deliberately omit subagents, MCP
  # tooling, tracing, permission enforcement, and to-do tracking.
  piMinimalPackageRefs = [
    "npm:pi-web-access@0.13.0"
    "npm:pi-verbosity-control@0.3.0"
    piLitellmProviderPackage
  ];
  mkPiMinimalSettings =
    defaults:
    builtins.toJSON (
      (builtins.removeAttrs defaults [ "subagents" ])
      // {
        packages = piMinimalPackageRefs;
      }
    );
  mkPiHerdrSettings =
    defaults:
    builtins.toJSON (
      defaults
      // {
        packages =
          map
            (
              package:
              if packageSource package == "npm:@tintinweb/pi-subagents@0.14.3" then
                "${self.packages.${system}.pi-herdr-agents}"
              else
                package
            )
            (
              builtins.filter (
                package:
                !(builtins.elem (packageSource package) [
                  "npm:@juicesharp/rpiv-btw@1.20.0"
                  "npm:context-mode@1.0.169"
                  "npm:pi-observational-memory@3.0.3"
                ])
              ) defaults.packages
            )
          ++ [
            "/Users/kisw/git/github.com/kirksw/pi-extensions/main"
            "npm:@plannotator/pi-extension"
          ];
      }
    );
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
      "litellm/openai/gpt-6-sol"
      "litellm/openai/gpt-6-luna"
      "litellm/minimax-m3"
      "litellm/glm-5.3"
      "litellm/glm-5.3-flash"
      "litellm/deepseek-flash"
      "litellm/deepseek-v4-pro"
    ];
    subagents.disableBuiltins = true;
  };

  piPersonalSettingsAttrs =
    piPersonalModelDefaults
    // piThemeSettings
    // {
      packages = piPersonalPackageRefs;
    };

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

  piWorkModelDefaults = {
    defaultProvider = "lunar";
    defaultModel = "anthropic.claude-sonnet-5-5";
    defaultThinkingLevel = "medium";
    # Scoped models ride the Lunar LiteLLM gateway (`lunar` provider, discovered
    # dynamically), so scope the whole catalog with a glob rather than pinning ids.
    enabledModels = [ "lunar/*" ];
  };

  piWorkSettingsAttrs =
    piWorkModelDefaults
    // piThemeSettings
    // {
      packages = piWorkPackageRefs;
      npmCommand = [ piNpmCommand ];
      subagents.disableBuiltins = true;
    };

  piWorkModels = builtins.toJSON {
    providers = {
      openai.baseUrl = "https://eu.api.openai.com/v1";
      mlx-dspark = piMlxDsparkProvider;
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
  piWorkAuth = builtins.toJSON {
    openai = {
      type = "api_key";
      key = "$OPENAI_API_KEY";
    };
  };

in
{
  inherit piPersonalPackageRefs piWorkAuth;

  targets = {
    pi = {
      personal = {
        "settings.json" = mkPiMinimalSettings piPersonalSettingsAttrs;
        "models.json" = piPersonalModels;
        "mcporter.json" = piEmptyMcporter;
        "env" = piPersonalEnv;
      };
      work = {
        "mcporter.json" = piWorkMcporter;
        "models.json" = piWorkModels;
        "settings.json" = mkPiMinimalSettings piWorkSettingsAttrs;
        "env" = piWorkEnv;
      };
      personal-default = {
        "mcporter.json" = piEmptyMcporter;
        "models.json" = piPersonalModels;
        "settings.json" = mkPiHerdrSettings piPersonalSettingsAttrs;
        "env" = mkPiPersonalEnv "personal-default";
      };
      work-default = {
        "mcporter.json" = piWorkMcporter;
        "models.json" = piWorkModels;
        "settings.json" = mkPiHerdrSettings piWorkSettingsAttrs;
        "env" = mkPiWorkEnv {
          base = "work-default";
          agenticosToolMode = "lazy";
        };
      };
      personal-browser = {
        "settings.json" = mkPiHerdrSettings piPersonalSettingsAttrs;
        "models.json" = piPersonalModels;
        "mcporter.json" = builtins.toJSON {
          imports = [ ];
          mcpServers.affine = {
            url = "http://nixos-ry6a.tail54de03.ts.net:31410/mcp";
            headers.Authorization = "Bearer \${AFFINE_MCP_HTTP_TOKEN}";
            lifecycle = "ephemeral";
          };
        };
        "env" = mkPiPersonalEnv "personal-browser" + ''
          export AFFINE_MCP_SOPS_FILE="${self}/secrets/assistants/affine-mcp.yaml"
        '';
      };
      work-browser = {
        "settings.json" = mkPiHerdrSettings (
          piWorkSettingsAttrs
          // {
            packages = builtins.filter (package: packageSource package != agenticOSPackage) piWorkPackageRefs;
          }
        );
        "models.json" = piWorkModels;
        "mcporter.json" = piEmptyMcporter;
        "env" = mkPiWorkEnv {
          base = "work-browser";
          agenticosToolMode = "lazy";
        };
      };
    };
  };
}
