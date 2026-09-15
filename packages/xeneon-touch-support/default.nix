{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "xeneon-touch-support";
  version = "0.1.0-unstable-2026-09-15";

  src = fetchFromGitHub {
    owner = "MatthiasReinholz";
    repo = "macos-touch-support-for-xeneon-edge";
    rev = "9a6823fe3f55448bd0ac233531dc6d73fbff19c5";
    hash = "sha256-C3EwlZwlTYk3f3XlyILF9d1NWl9aiksIC6fKYI5zESE=";
  };

  patches = [ ./safety.patch ];
  buildPhase = ''
    runHook preBuild
    $CC -fobjc-arc -Wall -Wextra -Wpedantic \
      -framework AppKit -framework ApplicationServices -framework IOKit \
      src/main.m -o XeneonTouchSupport
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    app="$out/Applications/XeneonTouchSupport.app/Contents"
    mkdir -p "$app/MacOS"
    cp XeneonTouchSupport "$app/MacOS/"
    cp packaging/Info.plist "$app/Info.plist"
    runHook postInstall
  '';

  meta = {
    description = "XENEON EDGE touch mapping workaround with local safety patches";
    homepage = "https://github.com/MatthiasReinholz/macos-touch-support-for-xeneon-edge";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.darwin;
  };
}
