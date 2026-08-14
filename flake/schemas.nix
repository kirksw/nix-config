{
  deploy = {
    version = 1;
    doc = ''
      The `deploy` flake output defines nodes and profiles for deploy-rs.
    '';
    allowIFD = false;
    inventory = output: {
      children.nodes.children = builtins.mapAttrs (nodeName: node: {
        children.profiles.children = builtins.mapAttrs (profileName: _: {
          what = "deploy-rs profile";
          shortDescription = "Deployment profile `${profileName}` for `${nodeName}`";
          derivationAttrPath = [ "path" ];
        }) node.profiles;
      }) output.nodes;
    };
  };
}
