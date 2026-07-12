{
  self,
  lib,
  system,
}:

let
  piHerdrPackage = "${self}/agents/packages/pi-herdr";

  piPackageRefs = [
    "npm:context-mode@1.0.169"
    "npm:pi-cmux@0.1.16"
    "npm:pi-cost@0.1.1"
    "npm:pi-dynamic-workflows@1.0.1"
    "npm:pi-goal-x@0.19.0"
    piHerdrPackage
    "npm:pi-mcp-adapter@2.8.0"
    "npm:pi-observational-memory@3.0.3"
    "npm:pi-permission-system@0.8.0"
    "npm:pi-simplify@0.2.2"
    "npm:pi-subagents@0.34.0"
    "npm:pi-web-access@0.13.0"
    "npm:pi-ponytail@0.1.2"
    "npm:@juicesharp/rpiv-ask-user-question@1.20.0"
    "npm:@juicesharp/rpiv-btw@1.20.0"
    "npm:@juicesharp/rpiv-todo@1.20.0"
  ];
  piFactoryPackageRefs = [
    "npm:pi-subagents@0.34.0"
    "npm:pi-mcp-adapter@2.8.0"
    "npm:pi-permission-system@0.8.0"
    "npm:pi-web-access@0.13.0"
  ];

  piPersonalSettings = builtins.toJSON {
    packages = piPackageRefs;
  };

  piHomeFactorySettings = builtins.toJSON {
    packages = piFactoryPackageRefs;
  };

  # Temporary shim until pi-coding-agent includes these models built-in.
  pi56Models = [
    {
      id = "gpt-5.6-sol";
      name = "GPT-5.6 Sol";
      reasoning = true;
      input = [
        "text"
        "image"
      ];
      cost = {
        input = 5;
        output = 30;
        cacheRead = 0.5;
        cacheWrite = 6.25;
      };
      contextWindow = 1050000;
      maxTokens = 128000;
    }
    {
      id = "gpt-5.6-terra";
      name = "GPT-5.6 Terra";
      reasoning = true;
      input = [
        "text"
        "image"
      ];
      cost = {
        input = 2.5;
        output = 15;
        cacheRead = 0.25;
        cacheWrite = 3.125;
      };
      contextWindow = 1050000;
      maxTokens = 128000;
    }
    {
      id = "gpt-5.6-luna";
      name = "GPT-5.6 Luna";
      reasoning = true;
      input = [
        "text"
        "image"
      ];
      cost = {
        input = 1;
        output = 6;
        cacheRead = 0.1;
        cacheWrite = 1.25;
      };
      contextWindow = 1050000;
      maxTokens = 128000;
    }
  ];

  piPersonalModels = builtins.toJSON {
    providers.zai.models = [
      {
        id = "glm-5.2";
        name = "GLM-5.2";
        reasoning = true;
        input = [ "text" ];
        cost = {
          input = 0;
          output = 0;
          cacheRead = 0;
          cacheWrite = 0;
        };
        compat = {
          supportsDeveloperRole = false;
          thinkingFormat = "zai";
          zaiToolStream = true;
        };
        thinkingLevelMap = {
          low = "high";
          high = "max";
          xhigh = "max";
        };
        contextWindow = 1000000;
        maxTokens = 131072;
      }
    ];
    providers.openai-codex.models = pi56Models;
  };

  piWorkModelDefaults = {
    defaultProvider = "openai";
    defaultModel = "gpt-5.4";
    defaultThinkingLevel = "medium";
    enabledModels = [
      "gpt-5.6-sol"
      "gpt-5.6-terra"
      "gpt-5.6-luna"
      "gpt-5.5"
      "gpt-5.4"
      "gpt-5.4-mini"
      "gpt-5.3-codex-spark"
      "claude-opus-4-8"
      "claude-sonnet-4-6"
    ];
  };

  piWorkSettings = builtins.toJSON (
    piWorkModelDefaults
    // {
      packages = piPackageRefs;
    }
  );

  piWorkFactorySettings = builtins.toJSON (
    piWorkModelDefaults
    // {
      packages = piFactoryPackageRefs;
    }
  );

  piWorkModels = builtins.toJSON {
    providers.openai = {
      baseUrl = "https://eu.api.openai.com/v1";
      models = pi56Models;
    };
  };

  piWorkMcp = builtins.toJSON {
    mcpServers = {
      "1password" = {
        command = "/Applications/1Password.app/Contents/MacOS/onepassword-mcp";
        lifecycle = "lazy";
      };
      granola = {
        url = "https://mcp.granola.ai/mcp";
        auth = "oauth";
        lifecycle = "lazy";
      };
      linear = {
        url = "https://mcp.linear.app/mcp";
        lifecycle = "lazy";
      };
      lunar-skills = {
        command = "${self.packages.${system}.lunar-skills-mcp}/bin/lunar-skills-mcp";
        lifecycle = "lazy";
      };
      hubble-mcp = {
        url = "https://hubble-mcp.prod.lunar.tech/mcp/";
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
  };

  piWorkEnv = ''
    if [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
      export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
    fi
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

    [features]
    image_generation = true
  '';

  codexPersonalRules = ''
    prefix_rule(pattern=["git", "add"], decision="allow")
    prefix_rule(pattern=["git", "clone"], decision="allow")
    prefix_rule(pattern=["git", "fetch"], decision="allow")
    prefix_rule(pattern=["git", "ls-remote"], decision="allow")
    prefix_rule(pattern=["git", "pull"], decision="allow")
    prefix_rule(pattern=["gh", "pr", "merge"], decision="allow")
    prefix_rule(pattern=["nix", "build"], decision="allow")
    prefix_rule(pattern=["nix", "eval", "--impure", "--expr"], decision="allow")
  '';

  codexWorkSettings = ''
    model = "gpt-5.5"
    model_reasoning_effort = "high"
    openai_base_url = "https://eu.api.openai.com/v1"
    plan_mode_reasoning_effort = "high"
    approvals_reviewer = "guardian_subagent"
    suppress_unstable_features_warning = true

    [features]
    image_generation = true

    [projects."/Users/kisw/git/github.com/lunarway/hubble-continuum"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-dbt"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/lunar-way-hubble-transformations"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/data-agents"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-flink-platform"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-rbac-controller"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-sandbox-finance"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/aws-lunar-data-prod-resources"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-wiki"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-starrocks"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/hubble-async-schema-ingestion"]
    trust_level = "trusted"

    [projects."/Users/kisw/git/github.com/lunarway/capi-workload-clusters"]
    trust_level = "trusted"

    [notice.model_migrations]
    "gpt-5.3-codex" = "gpt-5.4"

    [tui]
    theme = "catppuccin-latte"

    [tui.model_availability_nux]
    "gpt-5.5" = 4

  '';

  codexWorkRules = ''
    prefix_rule(pattern=["docker", "version"], decision="allow")
    prefix_rule(pattern=["git", "clone"], decision="allow")
    prefix_rule(pattern=["git", "fetch"], decision="allow")
    prefix_rule(pattern=["git", "ls-remote"], decision="allow")
    prefix_rule(pattern=["git", "pull"], decision="allow")
    prefix_rule(pattern=["git", "push", "origin"], decision="allow")
    prefix_rule(pattern=["nix", "develop", "--command", "mill"], decision="allow")
  '';
in
{
  inherit piWorkAuth;

  codexRules = {
    personal-default = codexPersonalRules;
    work-default = codexWorkRules;
  };

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
        "models.json" = piPersonalModels;
        "settings.json" = piPersonalSettings;
      };
      home-factory = {
        "models.json" = piPersonalModels;
        "settings.json" = piHomeFactorySettings;
      };
      work = {
        "mcp.json" = piWorkMcp;
        "models.json" = piWorkModels;
        "settings.json" = piWorkSettings;
        "env" = piWorkEnv;
      };
      work-factory = {
        "auth.json" = piWorkAuth;
        "models.json" = piWorkModels;
        "settings.json" = piWorkFactorySettings;
        "env" = piWorkEnv;
      };
    };
  };
}
