{ pkgs, lib, config, ... }:

{
  options = {
    homeModules.gcloud.enable = lib.mkEnableOption "enables gcloud";
  };

  config = lib.mkIf config.homeModules.gcloud.enable {
    home.packages = with pkgs; [
      (google-cloud-sdk.withExtraComponents [
        google-cloud-sdk.components.gke-gcloud-auth-plugin
        google-cloud-sdk.components.managed-flink-client
      ])
    ];
  };
}
