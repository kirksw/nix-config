{
  buildGoModule,
  curl,
  fetchFromGitHub,
  git,
  gnused,
  jq,
  lib,
  nix-update,
  writeShellScript,
}:

buildGoModule rec {
  pname = "gifgrep";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "gifgrep";
    rev = "d02a00600066efc612c184d8202bb37fa9ae31a8";
    hash = "sha256-1wr+A8McmODSibQd9qLg8DIuhgQnbbv07WjrDIhGXvo=";
  };

  vendorHash = "sha256-w8l8VB4QVJfCvzC9NsYz4ZEy+0pX6ulmSmT/tU1x3sA=";

  subPackages = [ "cmd/gifgrep" ];

  passthru.updateScript = writeShellScript "update-gifgrep" ''
    set -euo pipefail
    tag="$(${lib.getExe curl} -fsSL https://api.github.com/repos/steipete/gifgrep/releases?per_page=100 |
      ${lib.getExe jq} -r '[.[] | select((.draft | not) and (.prerelease | not)) | .tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))][0]')"
    test -n "$tag"
    version="''${tag#v}"
    rev="$(${lib.getExe git} ls-remote https://github.com/steipete/gifgrep.git "refs/tags/$tag^{}" |
      ${lib.getExe gnused} -n -E 's/\\t.*//p')"
    test -n "$rev"
    ${lib.getExe gnused} -i -E "s|rev = \"[^\"]+\";|rev = \"$rev\";|" "$repo_root/packages/gifgrep/default.nix"
    ${lib.getExe nix-update} --flake --version="$version" gifgrep
    echo "Updated gifgrep to $tag"
  '';

  meta = {
    description = "Terminal GIF search and browsing tool";
    homepage = "https://github.com/steipete/gifgrep";
    license = lib.licenses.mit;
    mainProgram = "gifgrep";
    platforms = lib.platforms.unix;
  };
}
