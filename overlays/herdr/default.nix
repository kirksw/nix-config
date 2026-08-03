final: prev:
let
  src = prev.fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    tag = "v0.8.0";
    hash = "sha256-empFQ+hrnCh2JhOzQRWSCLV0YoZC3DXW3bY6k8YuJjk=";
  };
in
{
  herdr = prev.herdr.overrideAttrs (_: {
    version = "0.8.0";
    inherit src;
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      pname = "herdr";
      version = "0.8.0";
      inherit src;
      hash = "sha256-E1lBgpTFZwNjeALeg/atwbDFL/XQbUnvCdX7ohbAHAc=";
    };
    zigDeps = prev.zig_0_15.fetchDeps {
      pname = "herdr";
      version = "0.8.0";
      src = "${src}/vendor/libghostty-vt";
      fetchAll = true;
      hash = "sha256-PnM+hZIlLyQwK8vJgd/Bhjt1lNIz06T8FahwliRmMrY=";
    };
  });
}
