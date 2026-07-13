{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "gifgrep";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "gifgrep";
    rev = "a91f5823fc8bdab49999e06ee6fc9772845b7904";
    hash = "sha256-GIsaFNB05hnNFCJwWnPML2Gh1sOedkUj8QFKeKIrOAI=";
  };

  vendorHash = "sha256-w8l8VB4QVJfCvzC9NsYz4ZEy+0pX6ulmSmT/tU1x3sA=";

  subPackages = [ "cmd/gifgrep" ];

  meta = {
    description = "Terminal GIF search and browsing tool";
    homepage = "https://github.com/steipete/gifgrep";
    license = lib.licenses.mit;
    mainProgram = "gifgrep";
    platforms = lib.platforms.unix;
  };
}
