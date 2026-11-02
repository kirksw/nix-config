{
  writeShellScriptBin,
  gh,
  nodejs,
  lib,
}:

# npm command for Pi profiles. `lunarctl agent init pi` installs a wrapper that
# routes `@lunarway` packages to GitHub Packages and supplies the registry token
# from `gh`. Fall back to plain npm while that wrapper is absent, so profiles
# that do not use Lunar packages keep installing from npmjs.
writeShellScriptBin "pi-npm" ''
  set -eu
  # Home Manager activation may not include user-installed tools in PATH.
  export PATH="${
    lib.makeBinPath [
      gh
      nodejs
    ]
  }:''${PATH:-/usr/bin:/bin}"
  wrapper="''${XDG_CONFIG_HOME:-$HOME/.config}/npm/pi/npm"
  if [ -x "$wrapper" ]; then
    exec "$wrapper" "$@"
  fi
  exec npm "$@"
''
