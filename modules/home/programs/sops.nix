{
  self,
  lib,
  config,
  pkgs,
  git,
  ssh,
  ...
}:

let
  profileNames = builtins.attrNames git.profiles;

  generateSshSecrets =
    {
      keys,
      secretsDir ? "${self}/secrets",
    }:
    lib.attrsets.mergeAttrsList (
      map (key: {
        "ssh/${key}/private" = {
          sopsFile = "${secretsDir}/ssh/${key}.yaml";
          key = "private";
          mode = "0400";
        };

        "ssh/${key}/public" = {
          sopsFile = "${secretsDir}/ssh/${key}.yaml";
          key = "public";
          mode = "0600";
        };
      }) keys
    );

  generateGitSecrets =
    {
      profileNames,
      secretsDir ? "${self}/secrets",
      properties ? [
        "name"
        "email"
        "org"
      ],
    }:
    builtins.listToAttrs (
      builtins.concatMap (
        profileName:
        builtins.map (property: {
          name = "git/${profileName}/${property}";
          value = {
            sopsFile = "${secretsDir}/git/${profileName}.yaml";
            key = "${property}";
            mode = "0400";
          };
        }) properties
      ) profileNames
    );

  generateGitTemplates =
    profileNames:
    builtins.listToAttrs (
      builtins.map (profileName: {
        name = "gitprofile-${profileName}";
        value = {
          mode = "0400";
          content = ''
            [user]
                name = ${config.sops.placeholder."git/${profileName}/name"}
                email = ${config.sops.placeholder."git/${profileName}/email"}
            [gpg]
                format = ssh
            [commit]
                gpgsign = true
            [user]
                signingKey = ${config.sops.secrets."ssh/${profileName}/private".path}
            [url "ssh://git@github.com-${profileName}:${profileName}/"]
                insteadOf = https://github.com/${profileName}/
                insteadOf = ssh://git@github.com/${profileName}/
                insteadOf = git@github.com/${profileName}/
          '';

        };
      }) profileNames
    );
in
{
  options = {
    homeModules.sops.enable = lib.mkEnableOption "enables sops";
    homeModules.sops.enableFluxKey = lib.mkEnableOption "enables flux AGE key deployment (for k8s-config secrets)";
  };

  config = lib.mkIf config.homeModules.sops.enable {
    home.activation.retrieveSopsAgeKey = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      SOPS_KEY_DIR="$HOME/.config/sops/age"
      SOPS_KEY_FILE="$SOPS_KEY_DIR/keys.txt"

      mkdir -p "$SOPS_KEY_DIR"

      if ! ${pkgs.proton-pass-cli}/bin/pass-cli item view \
          --vault-name macos \
          --item-title nix-sops-age \
          --field note > "$SOPS_KEY_FILE" 2>&1; then
        echo "ERROR: Failed to retrieve SOPS age key from Proton Pass"
        echo "Ensure pass-cli is logged in: pass-cli login"
        rm -f "$SOPS_KEY_FILE"
        exit 1
      fi

      chmod 400 "$SOPS_KEY_FILE"
      echo "Retrieved SOPS age key from Proton Pass"
    '';

    home.sessionVariables = {
      SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    };

    sops = {
      defaultSopsFormat = "yaml";
      age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      # define the required secrets for git profiles
      secrets =
        generateGitSecrets {
          inherit profileNames;
        }
        // generateSshSecrets {
          keys = ssh.keys;
        }
        // {
          "k8s/homelab" = {
            sopsFile = "${self}/secrets/k8s/homelab.yaml";
            key = "config";
            mode = "0400";
          };
          "k8s/node" = {
            sopsFile = "${self}/secrets/k8s/node.yaml";
            key = "secret";
            mode = "0400";
          };
        }
        // lib.optionalAttrs config.homeModules.sops.enableFluxKey {
          "k8s/flux" = {
            sopsFile = "${self}/secrets/k8s/flux.yaml";
            key = "key";
            mode = "0400";
          };
        };

      templates = generateGitTemplates profileNames;
    };

    # Make flux AGE key available for sops CLI usage (e.g., decrypting k8s-config secrets)
    home.activation.appendFluxAgeKey = lib.mkIf config.homeModules.sops.enableFluxKey (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        FLUX_KEY_PATH="$HOME/.config/sops/age/keys.txt"
        FLUX_KEY_SECRET="${config.sops.secrets."k8s/flux".path}"

        # Ensure the directory exists
        mkdir -p "$(dirname "$FLUX_KEY_PATH")"

        # Append the flux key if not already present
        if [[ -f "$FLUX_KEY_SECRET" ]]; then
          FLUX_KEY="$(cat "$FLUX_KEY_SECRET")"
          if ! grep -qF "$FLUX_KEY" "$FLUX_KEY_PATH" 2>/dev/null; then
            echo "# Flux key for k8s-config (added by nix-darwin)" >> "$FLUX_KEY_PATH"
            echo "$FLUX_KEY" >> "$FLUX_KEY_PATH"
            echo "Added flux AGE key to $FLUX_KEY_PATH"
          fi
        fi
      ''
    );
  };
}
