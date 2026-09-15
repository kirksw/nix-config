{
  lib,
  stdenv,
  swift,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "edge-observatory";
  version = "1.0.0";
  nativeBuildInputs = [ swift ];
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./EdgeObservatory.swift
      ./UnreadTracker.swift
      ./ProcessRunner.swift
      ./SnapshotModel.swift
      ./TouchRuntime.m
      ./Info.plist
      ./app.js
      ./index.html
      ./style.css
      ./TOUCH-LICENSE
    ];
  };
  buildPhase = ''
    runHook preBuild
    mkdir -p build/"EDGE Observatory.app"/Contents/{MacOS,Resources}
    clang -fobjc-arc -Wall -Wextra -Wpedantic -c TouchRuntime.m -o TouchRuntime.o \
      -framework AppKit -framework ApplicationServices -framework IOKit -framework Foundation
    swiftc EdgeObservatory.swift UnreadTracker.swift ProcessRunner.swift SnapshotModel.swift TouchRuntime.o \
      -o 'build/EDGE Observatory.app/Contents/MacOS/EDGE Observatory' \
      -framework AppKit -framework EventKit -framework CoreLocation -framework WebKit
    cp index.html style.css app.js TOUCH-LICENSE 'build/EDGE Observatory.app/Contents/Resources/'
    cp Info.plist 'build/EDGE Observatory.app/Contents/Info.plist'
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R 'build/EDGE Observatory.app' "$out/Applications/"
    runHook postInstall
  '';
  meta = {
    description = "Single-process read-only EDGE Observatory dashboard";
    platforms = lib.platforms.darwin;
    license = lib.licenses.gpl3Only;
  };
})
