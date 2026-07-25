final: prev:
let
  src = prev.fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    tag = "v0.7.5";
    hash = "sha256-3BA8eredGku+vsL2Af7sUf43QiArR5XTHNrI+X11vFM=";
  };
in
{
  herdr = prev.herdr.overrideAttrs (_: {
    version = "0.7.5";
    inherit src;
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      pname = "herdr";
      version = "0.7.5";
      inherit src;
      hash = "sha256-lWnc0Ka0hp7bbm+dkKKj22Dbk+Cwrld86romXs3lzBs=";
    };
    zigDeps = prev.zig_0_15.fetchDeps {
      pname = "herdr";
      version = "0.7.5";
      src = "${src}/vendor/libghostty-vt";
      fetchAll = true;
      hash = "sha256-PnM+hZIlLyQwK8vJgd/Bhjt1lNIz06T8FahwliRmMrY=";
    };
  });
}
