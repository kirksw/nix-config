{
  "pi-subagents" = {
    enabled = true;
    npmName = "pi-subagents";
    version = "0.28.0";
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
    version = "1.19.1";
    aliases = [ "rpiv-todos" ];
    types = [ "extension" ];
    source = "https://pi.dev/packages/%40juicesharp/rpiv-todo";
  };

  "pi-kanban" = {
    enabled = true;
    npmName = "pi-kanban";
    version = "1.0.0";
    types = [ "extension" ];
    source = "https://pi.dev/packages/pi-kanban";
  };

  "context-mode" = {
    enabled = true;
    npmName = "context-mode";
    version = "1.0.162";
    types = [
      "extension"
      "skill"
    ];
    source = "https://pi.dev/packages/context-mode";
  };

  "pi-web-access" = {
    enabled = true;
    npmName = "pi-web-access";
    version = "0.10.7";
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
    version = "1.19.1";
    types = [ "extension" ];
    source = "https://pi.dev/packages/%40juicesharp/rpiv-btw";
  };

  "pi-lens" = {
    enabled = true;
    npmName = "pi-lens";
    version = "3.8.50";
    types = [
      "extension"
      "skill"
    ];
    source = "https://pi.dev/packages/pi-lens";
  };

  ponytail = {
    enabled = true;
    ref = "git:github.com/DietrichGebert/ponytail@687c1b339872289d70f65c5eaabce850b1663867";
    version = "687c1b339872289d70f65c5eaabce850b1663867";
    types = [
      "extension"
      "skill"
    ];
    source = "https://github.com/DietrichGebert/ponytail";
  };
}
