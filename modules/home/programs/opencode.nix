{
  self,
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  swePrunerCommand = config.homeModules.swePrunerMcp.command;
  swePrunerStatsFile = "${homeDir}/.cache/swe-pruner/stats.json";
  swePrunerModelPath = "${homeDir}/.cache/swe-pruner/models/code-pruner";

  swePrunerMcp = lib.optionalAttrs (config.homeModules.swePrunerMcp.enable && swePrunerCommand != null) {
    swe-pruner = {
      type = "local";
      enabled = true;
      command = [ swePrunerCommand ];
      environment = {
        MODEL_PATH = swePrunerModelPath;
        STATS_FILE = swePrunerStatsFile;
      };
    };
  };

  # --- personal profile config ---
  personalMcp = {
    "web-reader" = {
      type = "remote";
      url = "https://api.z.ai/api/mcp/web_reader/mcp";
      enabled = false;
      headers = {
        Authorization = "Bearer {env:zai_token}";
      };
    };
    zread = {
      type = "remote";
      url = "https://api.z.ai/api/mcp/zread/mcp";
      enabled = false;
      headers = {
        Authorization = "Bearer {env:zai_token}";
      };
    };
    web-search-prime = {
      type = "remote";
      url = "https://api.z.ai/api/mcp/web_search_prime/mcp";
      enabled = false;
      headers = {
        Authorization = "Bearer {env:zai_token}";
      };
    };
    zai-mcp-server = {
      type = "local";
      enabled = false;
      command = [
        "npx"
        "-y"
        "@z_ai/mcp-server"
      ];
      environment = {
        Z_AI_API_KEY = "{env:zai_token}";
        Z_AI_MODE = "ZAI";
      };
    };
  } // swePrunerMcp;

  personalConfig = {
    "$schema" = "https://opencode.ai/config.json";

    provider = {
      ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "ollama local models";
        options = {
          baseurl = "http://localhost:11434/v1";
          apikey = "ollama";
        };
        models = {
          "qwen3.5-coder:9b" = {
            name = "qwen 3.5 coder 9b (fast)";
          };
          "qwen3.5-coder:35b" = {
            name = "qwen 3.5 coder 35b (main)";
          };
        };
      };

      zai-coding-plan = {
        name = "zai-coding-plan";
        options = {
          apiKey = "{env:zai_token}";
        };
      };

      anthropic = {
        name = "anthropic";
      };

      openai = {
        name = "openai";
      };

      minimax = {
        name = "minimax";
        options = {
          apiKey = "{env:MINIMAX_API_KEY}";
        };
      };
    };

    agent = {
      explore = {
        model = "openai/gpt-5.3-codex";
      };
    };

    compaction = {
      auto = true;
      prune = true;
    };

    watcher = {
      ignore = [ ".git/**" ];
    };

    keybinds = {
      input_submit = "return";
      input_newline = "shift+return,ctrl+return,alt+return";
    };

    mcp = personalMcp;
  };

  # --- work profile config ---
  workMcp = swePrunerMcp;

  workConfig = {
    "$schema" = "https://opencode.ai/config.json";

    provider = {
      anthropic = {
        name = "anthropic";
      };

      openai = {
        name = "openai";
        options = {
          baseURL = "https://eu.api.openai.com/v1";
        };
      };
    };

    agent = {
      explore = {
        model = "openai/gpt-5.3-codex";
      };
    };

    compaction = {
      auto = true;
      prune = true;
    };

    watcher = {
      ignore = [ ".git/**" ];
    };

    keybinds = {
      input_submit = "return";
      input_newline = "shift+return,ctrl+return,alt+return";
    };

    mcp = workMcp;
  };

  # --- profile paths ---
  profileBase = "${homeDir}/.config/opencode/profiles";
  dataProfileBase = "${homeDir}/.local/share/opencode/profiles";

  # --- wrapper ---
  mkOpencodeWrapper = pkgs.writeShellScriptBin "opencode" ''
    set -euo pipefail

    ZAI_SECRET_PATH="${config.sops.secrets."zai".path}"
    MINIMAX_SECRET_PATH="${config.sops.secrets."minimax".path}"
    LUNAR_OPENAI_KEY_PATH="${config.sops.secrets."api/lunar/openai".path}"
    LUNAR_ANTHROPIC_KEY_PATH="${config.sops.secrets."api/lunar/anthropic".path}"
    OPENCODE_BIN="${pkgs.llm-agents.opencode}/bin/opencode"

    is_work_project() {
      [[ "$(pwd)" == ~/git/github.com/lunarway?(/*) ]]
    }

    if is_work_project; then
      if [[ ! -f "$LUNAR_OPENAI_KEY_PATH" ]]; then
        echo "error: missing work API key at $LUNAR_OPENAI_KEY_PATH" >&2
        exit 1
      fi
      if [[ ! -f "$LUNAR_ANTHROPIC_KEY_PATH" ]]; then
        echo "error: missing Claude API key at $LUNAR_ANTHROPIC_KEY_PATH" >&2
        echo "add 'anthropic' key to secrets/api/lunar.yaml with sops" >&2
        exit 1
      fi
      export XDG_CONFIG_HOME="${profileBase}/work"
      export XDG_DATA_HOME="${dataProfileBase}/work"
      export OPENAI_API_KEY="$(cat "$LUNAR_OPENAI_KEY_PATH")"
      export OPENAI_BASE_URL="https://eu.api.openai.com/v1"
      export ANTHROPIC_API_KEY="$(cat "$LUNAR_ANTHROPIC_KEY_PATH")"
      echo "opencode: using work profile (lunar)" >&2
      exec -a opencode "$OPENCODE_BIN" "$@"
    else
      if [[ ! -f "$ZAI_SECRET_PATH" ]]; then
        echo "error: secret not found at $ZAI_SECRET_PATH" >&2
        echo "make sure sops is enabled and secrets are activated" >&2
        exit 1
      fi
      export XDG_CONFIG_HOME="${profileBase}/personal"
      export XDG_DATA_HOME="${dataProfileBase}/personal"
      export zai_token="$(cat "$ZAI_SECRET_PATH")"
      export MINIMAX_API_KEY="$(cat "$MINIMAX_SECRET_PATH")"
      echo "opencode: using personal profile" >&2
      exec -a opencode "$OPENCODE_BIN" "$@"
    fi
  '';
in
{
  options = {
    homeModules.opencode.enable = lib.mkEnableOption "enables opencode";
  };

  config = lib.mkIf config.homeModules.opencode.enable {
    sops.secrets = {
      "zai" = {
        sopsFile = "${self}/secrets/api/default.yaml";
        key = "zai";
        mode = "0400";
      };
      "minimax" = {
        sopsFile = "${self}/secrets/api/default.yaml";
        key = "minimax";
        mode = "0400";
      };
      "api/lunar/openai" = {
        sopsFile = "${self}/secrets/api/lunar.yaml";
        key = "openai";
        mode = "0400";
      };
      "api/lunar/anthropic" = {
        sopsFile = "${self}/secrets/api/lunar.yaml";
        key = "anthropic";
        mode = "0400";
      };
    };

    home.packages = [
      mkOpencodeWrapper
    ];

    # personal profile config
    xdg.configFile."opencode/profiles/personal/opencode/opencode.json".text =
      builtins.toJSON personalConfig;

    # work profile config
    xdg.configFile."opencode/profiles/work/opencode/opencode.json".text =
      builtins.toJSON workConfig;
  };
}
