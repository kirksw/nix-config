final: prev: {
  direnv = prev.direnv.overrideAttrs (old: {
    version = "2.36.0";
    src = prev.fetchFromGitHub {
      owner = "direnv";
      repo = "direnv";
      rev = "v2.36.0";
      hash = "sha256-xqHc4Eb0mHQezmElJv20AMNQPgusXdvskNmlO+JP1lw=";
    };
    vendorHash = "sha256-+7HnbJ6cIzYHkEJVcp2IydHyuqD5PfdL6TUcq7Dpluk=";
    env = (old.env or { }) // {
      CGO_ENABLED = 1;
    };
  });
}
