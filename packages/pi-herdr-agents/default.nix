{
  stdenvNoCC,
  fetchzip,
  nodejs,
  pi,
}:

stdenvNoCC.mkDerivation {
  pname = "pi-herdr-agents";
  version = "1.7.0-local.1";
  src = fetchzip {
    url = "https://registry.npmjs.org/pi-herdr-agents/-/pi-herdr-agents-1.7.0.tgz";
    hash = "sha256-T5UZlh1n4oZ5qW94zejyTYd6FcbUgZQUhl+J2NTauiw=";
  };
  patches = [ ./wrapper-overrides.patch ];
  dontBuild = true;
  nativeCheckInputs = [ nodejs ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ln -s ${pi}/lib/node_modules node_modules
    cp ${./wrapper-overrides.test.mjs} wrapper-overrides.test.mjs
    node --experimental-strip-types --test wrapper-overrides.test.mjs
    rm node_modules wrapper-overrides.test.mjs
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R . "$out/"
    runHook postInstall
  '';
}
