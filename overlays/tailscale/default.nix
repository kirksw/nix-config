final: prev: {
  tailscale = prev.tailscale.overrideAttrs (old: {
    # Disable tests to fix build timeouts/sandboxing issues
    doCheck = false;

    # Optional: Speed up build by disabling sub-packages check if doCheck doesn't cover everything
    checkFlags = [ "-skip=Test" ];
  });
}
