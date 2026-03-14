{ deploy-rs, deploy }:
builtins.mapAttrs (system: deployLib: deployLib.deployChecks deploy) deploy-rs.lib
