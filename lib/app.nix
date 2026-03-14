{
  lib,
  inputs,
}:

let
  inherit (inputs) nixpkgs self;

  mkApp = scriptName: system:
    let
      pkgs = import nixpkgs { inherit system; };
      descriptions = {
        build = "Build the system generation for the selected platform.";
        switch = "Build and switch to a new system generation.";
        rollback = "Rollback to a previous system generation.";
      };
    in
    {
      type = "app";
      program = "${(pkgs.writeScriptBin scriptName ''
        #!${pkgs.runtimeShell}
        PATH=${pkgs.git}/bin:$PATH
        echo "Running ${scriptName} for ${system}"
        exec ${self}/apps/${system}/${scriptName}
      '')}/bin/${scriptName}";
      meta = {
        description = descriptions.${scriptName} or "Repository helper app.";
      };
    };
in
{
  inherit mkApp;
}
