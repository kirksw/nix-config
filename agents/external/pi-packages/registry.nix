{
  "pi-subagents" = {
    enabled = true;
    npmName = "pi-subagents";
    version = "0.31.0";
    types = [
      "extension"
      "skill"
      "prompt"
    ];
    source = "https://pi.dev/packages/pi-subagents";
  };

  "rpiv-todo" = {
    enabled = true;
    npmName = "@juicesharp/rpiv-todo";
    version = "1.20.0";
    aliases = [ "rpiv-todos" ];
    types = [ "extension" ];
    source = "https://pi.dev/packages/%40juicesharp/rpiv-todo";
  };

  "rpiv-ask-user-question" = {
    enabled = true;
    npmName = "@juicesharp/rpiv-ask-user-question";
    version = "1.20.0";
    types = [ "extension" ];
    source = "https://pi.dev/packages/%40juicesharp/rpiv-ask-user-question";
  };

  "pi-kanban" = {
    enabled = false;
    npmName = "pi-kanban";
    version = "1.0.0";
    types = [ "extension" ];
    source = "https://pi.dev/packages/pi-kanban";
  };

  "pi-goal-x" = {
    enabled = true;
    ref = "git:github.com/tmonk/pi-goal-x@68ed6de10201cef2fb262b64ab40d75a4e0c6098";
    version = "0.18.8";
    types = [ "extension" ];
    source = "https://github.com/tmonk/pi-goal-x";
  };

  "pi-observational-memory" = {
    enabled = true;
    npmName = "pi-observational-memory";
    version = "3.0.2";
    types = [ "extension" ];
    source = "https://pi.dev/packages/pi-observational-memory";
  };

  "pi-permission-system" = {
    enabled = true;
    npmName = "pi-permission-system";
    version = "0.7.1";
    types = [ "extension" ];
    source = "https://pi.dev/packages/pi-permission-system";
  };

  "context-mode" = {
    enabled = true;
    npmName = "context-mode";
    version = "1.0.169";
    types = [
      "extension"
      "skill"
    ];
    source = "https://pi.dev/packages/context-mode";
  };

  "pi-web-access" = {
    enabled = true;
    npmName = "pi-web-access";
    version = "0.13.0";
    aliases = [ "pi-web-acess" ];
    types = [
      "extension"
      "skill"
    ];
    source = "https://pi.dev/packages/pi-web-access";
  };

  "pi-dynamic-workflows" = {
    enabled = true;
    npmName = "pi-dynamic-workflows";
    version = "1.0.1";
    types = [ "extension" ];
    source = "https://pi.dev/packages/pi-dynamic-workflows";
  };

  "pi-cost" = {
    enabled = true;
    npmName = "pi-cost";
    version = "0.1.1";
    types = [ "extension" ];
    source = "https://pi.dev/packages/pi-cost";
  };

  "pi-simplify" = {
    enabled = true;
    npmName = "pi-simplify";
    version = "0.2.2";
    types = [ "extension" ];
    source = "https://pi.dev/packages/pi-simplify";
  };

  "rpiv-btw" = {
    enabled = true;
    npmName = "@juicesharp/rpiv-btw";
    version = "1.20.0";
    types = [ "extension" ];
    source = "https://pi.dev/packages/%40juicesharp/rpiv-btw";
  };

  "pi-lens" = {
    enabled = false;
    npmName = "pi-lens";
    version = "3.8.62";
    types = [
      "extension"
      "skill"
    ];
    source = "https://pi.dev/packages/pi-lens";
  };

  ponytail = {
    enabled = true;
    ref = "git:github.com/DietrichGebert/ponytail@16f6cbf4b87792938e47b0f8c650b6d80fcbc98c";
    version = "16f6cbf4b87792938e47b0f8c650b6d80fcbc98c";
    types = [
      "extension"
      "skill"
    ];
    source = "https://github.com/DietrichGebert/ponytail";
  };

  "pi-cmux" = {
    enabled = true;
    ref = "git:github.com/gtwatts/pi-cmux@0b6010b93bd7f2cd29b842dd9f2619b23645356f";
    version = "0b6010b93bd7f2cd29b842dd9f2619b23645356f";
    types = [ "extension" ];
    source = "https://github.com/gtwatts/pi-cmux";
  };
}
