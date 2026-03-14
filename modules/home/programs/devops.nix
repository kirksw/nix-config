{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  kube1 = config.sops.secrets."k8s/homelab".path;
  kube2 = "${inputs.lunar-tools.packages.${pkgs.stdenv.hostPlatform.system}.lunar-zsh-plugin}/.kube/config";
  writableKubeconfig = "${config.home.homeDirectory}/.kube/config";
  mergeScript = pkgs.writeShellScript "merge-kubeconfig" ''
    # Ensure .kube directory exists
    mkdir -p "$HOME/.kube"

    # Merge read-only configs into writable config
    # Only update if source configs are newer or writable config doesn't exist
    if [[ ! -f ${writableKubeconfig} ]] || [[ ${kube1} -nt ${writableKubeconfig} ]] || [[ ${kube2} -nt ${writableKubeconfig} ]]; then
      echo "Merging kubeconfig files into writable config..."
      KUBECONFIG=${kube1}:${kube2} ${pkgs.kubectl}/bin/kubectl config view --flatten > ${writableKubeconfig}
      chmod 600 ${writableKubeconfig}
    fi
  '';
in
{
  options = {
    homeModules.devops.enable = lib.mkEnableOption "enables devops tooling";
  };

  config = lib.mkIf config.homeModules.devops.enable {
    home.packages = with pkgs; [
      # IaC
      tenv

      # container/kubernetes
      awscli2
      fluxcd
      docker
      kustomize
      kubeconform
      kubectl
      kubectl-slice
      kubelogin-oidc
      krew
      kubernetes-helm
      argocd
      k9s
    ];

    home.sessionPath = [
      "${config.home.homeDirectory}/.krew/bin"
    ];

    # Install merge script
    home.file.".local/bin/merge-kubeconfig" = {
      source = mergeScript;
      executable = true;
    };

    home.sessionVariables = {
      KUBECONFIG = writableKubeconfig;
    };

    # Add merge script to zsh initialization (runs on shell start, but script checks if merge is needed)
    # Home Manager will merge this with other initExtra content
    programs.zsh.initContent = ''
      # Merge kubeconfig files if needed (only updates when source configs change)
      ${mergeScript} >/dev/null 2>&1
      # Ensure KUBECONFIG points to writable file (sessionVariables should handle this, but explicit for clarity)
      export KUBECONFIG="${writableKubeconfig}"
    '';
  };
}
