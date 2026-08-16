{
  self,
  lib,
  system,
}:

let
  piHerdrPackage = "${self}/agents/packages/pi-herdr";
  piTodoPackage = "${self}/agents/packages/pi-todo";
  piAgentJournalPackage = "${self}/agents/packages/pi-agent-journal";
  piMlflowTracerPackage = "${self.packages.${system}.pi-mlflow-tracer}";
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
    piHerdrPackage
    "npm:@tintinweb/pi-subagents@0.14.3"
    "npm:pi-observational-memory@3.0.3"
    "npm:pi-permission-system@0.8.0"
    "npm:pi-simplify@0.2.2"
    "npm:pi-web-access@0.13.0"
    "npm:@pi-plugins/fast-mode@0.1.8"
    "npm:@juicesharp/rpiv-ask-user-question@1.20.0"
    "npm:@juicesharp/rpiv-btw@1.20.0"
    piTodoPackage
    piAgentJournalPackage
    piMlflowTracerPackage
  ];
  piPersonalPackageRefs = piPackageRefs ++ [ "npm:bladebro@3.1.4" ];
  piWorkPackageRefs = piPackageRefs ++ [ agenticOSPackage ];
  piFactoryPackageRefs = [
    piHerdrPackage
    piMlflowTracerPackage
    "npm:@tintinweb/pi-subagents@0.14.3"
    "npm:pi-permission-system@0.8.0"
    "npm:pi-web-access@0.13.0"
  ];
  piWorkFactoryPackageRefs = piFactoryPackageRefs ++ [ piAgentJournalPackage ];

  piPersonalSettings = builtins.toJSON {
    defaultProvider = "zai";
    defaultModel = "glm-5.2";
    defaultThinkingLevel = "medium";
    enabledModels = [
      "gpt-5.6-sol"
      "gpt-5.6-terra"
      "gpt-5.6-luna"
      "minimax-m3"
      "glm-5.2"
      "grok-4.5"
      "kimi-k3"
      "qwen3.7-max"
      "deepseek-v4-pro"
    ];
    packages = piPersonalPackageRefs;
    subagents.disableBuiltins = true;
  };

  piHomeFactorySettings = builtins.toJSON {
    packages = piFactoryPackageRefs;
    subagents.disableBuiltins = true;
  };

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
      "gpt-5.3-codex-spark"
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
    // {
      packages = piWorkPackageRefs;
      subagents.disableBuiltins = true;
    }
  );

  piWorkFactorySettings = builtins.toJSON (
    piWorkModelDefaults
    // {
      packages = piWorkFactoryPackageRefs;
      subagents.disableBuiltins = true;
    }
  );

  piWorkModels = builtins.toJSON {
    providers.openai.baseUrl = "https://eu.api.openai.com/v1";
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

  piWorkMcporter = builtins.toJSON {
    imports = [ ];
    mcpServers = lib.mapAttrs (_: server: server // { lifecycle = "ephemeral"; }) piWorkMcpServers;
  };

  piPersonalEnv = ''
    export MLFLOW_TRACKING_URI="https://mlflow.cntd.io"
    export MLFLOW_EXPERIMENT_NAME="pi-home-traces"
    export MCPORTER_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents/pi/bases/personal/settings/mcporter.json"
  '';

  piWorkEnv = ''
    export MLFLOW_TRACKING_URI="https://mlflow.cntd.io"
    export MLFLOW_EXPERIMENT_NAME="pi-work-traces"
    export AGENTICOS_INSTANCE="lunarOS"
    export MCPORTER_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents/pi/bases/work/settings/mcporter.json"
    if [ -n "''${LUNAR_OPENAI_API_KEY:-}" ]; then
      export OPENAI_API_KEY="$LUNAR_OPENAI_API_KEY"
    fi
    export AWS_PROFILE="lw-employee-ai"
    export AWS_REGION="eu-west-1"
    export AWS_SDK_LOAD_CONFIG=1
  '';

  piHomeFactoryEnv = ''
    export MLFLOW_TRACKING_URI="https://mlflow.cntd.io"
    export MLFLOW_EXPERIMENT_NAME="pi-home-traces"
    export MCPORTER_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents/pi/bases/home-factory/settings/mcporter.json"
  '';

  piWorkFactoryEnv = ''
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
  inherit piWorkAuth;

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
        "mcporter.json" = piEmptyMcporter;
        "env" = piPersonalEnv;
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
      work-factory = {
        "auth.json" = piWorkAuth;
        "mcporter.json" = piEmptyMcporter;
        "models.json" = piWorkModels;
        "settings.json" = piWorkFactorySettings;
        "env" = piWorkFactoryEnv;
      };
    };
  };
}
