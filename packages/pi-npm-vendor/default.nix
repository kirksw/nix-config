{
  self,
  pkgs,
  lib,
}:
# Vendor every Nix-declared Pi npm package into a per-base, content-addressed
# install set and publish runtime settings.json with local package paths, so
# Pi never installs packages at session startup.
#
# Called from `sync-agents` and Home Manager activation, both with --strict.
# Fail-closed invariant: when any declared npm package cannot be vendored and
# verified, the run fails without publishing settings. Previous usable
# settings are preserved; a fresh setup simply fails without settings.
#
# Transaction: each spec set installs into
# `<config>/pi/npm/<base>/set-<hash>/`, where the hash covers the pinned
# specs. The live set of a previous generation is never mutated: a failed
# build of a new set leaves the old set and the settings pointing at it
# untouched. Settings are published (atomically) only after the set verifies.
#
# npm semantics mirror Pi's managed install: one batch
# `install <specs> --prefix <set> --legacy-peer-deps` per base through the
# pi-npm registry wrapper (GitHub Packages auth for @lunarway packages).
let
  system = pkgs.stdenv.hostPlatform.system;
  agentBaseSettings = import ../../agents/base-settings.nix {
    inherit
      self
      lib
      system
      ;
  };
  baseSettingsFiles = lib.mapAttrs (
    base: files: pkgs.writeText "pi-npm-vendor-${base}-settings.json" files."settings.json"
  ) agentBaseSettings.targets.pi;
  vendorManifest = pkgs.writeText "pi-npm-vendor-manifest.json" (builtins.toJSON baseSettingsFiles);
in
pkgs.writeShellScriptBin "pi-npm-vendor" ''
  set -euo pipefail

  usage() {
    cat <<'EOF'
  Usage: pi-npm-vendor [--dry-run] [--strict]

  Install Nix-declared Pi npm packages into
  ''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents/pi/npm/<base>/set-<hash> and
  publish the runtime base settings.json with those local paths.

  The tool is fail-closed: it exits non-zero and leaves previous settings in
  place when any declared package cannot be vendored and verified, when the
  npm install fails, or when existing settings are not valid JSON. Pi must
  never fall back to installing npm packages at startup.
  --dry-run  Print planned installs and the publish; change nothing.
  --strict   Accepted for explicitness; strictness is always enforced.
  --manifest Print the baked base manifest path and exit.
  PI_OFFLINE=1 skips npm install attempts (Pi's offline switch); a fully
  cached set still verifies and publishes. PI_NPM_BIN and
  PI_NPM_TIMEOUT_SECS override the npm command and its timeout.
  EOF
  }

  DRY_RUN=0
  MANIFEST='${vendorManifest}'
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=1 ;;
      --strict) ;;
      --manifest) printf '%s\n' "$MANIFEST"; exit 0 ;;
      -h|--help) usage; exit 0 ;;
      *)
        echo "pi-npm-vendor: unexpected argument: $arg" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  CONFIG_BASE="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-agents"
  NPM_ROOT_BASE="$CONFIG_BASE/pi/npm"
  JQ='${pkgs.jq}/bin/jq'
  COREUTILS='${pkgs.coreutils}/bin'
  CMP='${pkgs.diffutils}/bin/cmp'
  PI_NPM_BIN="''${PI_NPM_BIN:-${self.packages.${system}.pi-npm}/bin/pi-npm}"
  TIMEOUT_SECS="''${PI_NPM_TIMEOUT_SECS:-900}"
  OFFLINE=0
  if [ "''${PI_OFFLINE:-0}" = "1" ]; then
    OFFLINE=1
  fi

  FAILED_BASES=""

  # Pi's parseNpmSpec semantics: package names carry at most one leading `@`;
  # the trailing `@`-separated segment, when present, is the version.
  SPEC_FIELDS='[.packages // [] | .[] | (if type == "object" then .source else . end)
    | select(type == "string" and startswith("npm:"))
    | .[4:]
    | {
        spec: .,
        name: (if startswith("@") then "@" + (split("@")[1]) else split("@")[0] end),
        version: (if startswith("@") then (split("@")[2] // "") else (split("@")[1] // "") end)
      }]'

  # Exact pins must match exactly; unpinned sources accept any installed
  # version, matching Pi's installedNpmMatchesConfiguredVersion.
  spec_satisfied() {
    set_root="$1"
    name="$2"
    version="$3"
    pkg_json="$set_root/node_modules/$name/package.json"
    [ -f "$pkg_json" ] || return 1
    installed="$($JQ -r '.version // empty' "$pkg_json" 2>/dev/null)" || return 1
    [ -n "$installed" ] || return 1
    if [ -n "$version" ]; then
      [ "$installed" = "$version" ]
    else
      return 0
    fi
  }

  set_hash() {
    printf '%s' "$1" | $JQ -c 'sort_by(.name)' | "$COREUTILS/sha256sum" | "$COREUTILS/cut" -c1-12
  }

  install_set() {
    base="$1"
    set_root="$2"
    shift 2

    if [ "$OFFLINE" -eq 1 ]; then
      echo "pi-npm-vendor: $base: PI_OFFLINE=1; skipping npm install for $set_root" >&2
      return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "pi-npm-vendor: $base: DRY-RUN would install $* into $set_root"
      return 0
    fi

    "$COREUTILS/mkdir" -p "$set_root"
    if [ ! -f "$set_root/.gitignore" ]; then
      printf '*\n!.gitignore\n' > "$set_root/.gitignore"
    fi
    if [ ! -f "$set_root/package.json" ]; then
      printf '{"name":"pi-npm-vendor-%s","private":true}\n' "$base" > "$set_root/package.json"
    fi
    echo "pi-npm-vendor: $base: installing $* into $set_root through $PI_NPM_BIN"
    if ! "$COREUTILS/timeout" "$TIMEOUT_SECS" "$PI_NPM_BIN" \
      install "$@" --prefix "$set_root" --legacy-peer-deps; then
      echo "pi-npm-vendor: $base: npm install failed; previous settings preserved" >&2
      return 1
    fi
  }

  # Pin the set package.json to the exact vendored versions so resumed or
  # repeated installs cannot drift inside a ^ range, and record provenance.
  record_vendored_state() {
    base="$1"
    set_root="$2"
    specs_json="$3"

    versions_json="{}"
    while IFS= read -r name; do
      pkg_json="$set_root/node_modules/$name/package.json"
      installed="$($JQ -r '.version // empty' "$pkg_json" 2>/dev/null)" || continue
      [ -n "$installed" ] || continue
      versions_json="$($JQ -c --arg name "$name" --arg version "$installed" \
        '.[$name] = $version' <<<"$versions_json")"
    done < <($JQ -r '.[].name' <<<"$specs_json")

    root_tmp="$($COREUTILS/mktemp "$set_root/package.json.vendor.XXXXXX")"
    if $JQ --argjson deps "$versions_json" --arg name "pi-npm-vendor-$base" \
      '. + {name: $name, private: true, dependencies: $deps}' \
      "$set_root/package.json" > "$root_tmp" \
      && $JQ empty "$root_tmp" 2>/dev/null; then
      "$COREUTILS/mv" "$root_tmp" "$set_root/package.json"
    else
      "$COREUTILS/rm" -f "$root_tmp"
      echo "pi-npm-vendor: $base: could not normalize $set_root/package.json" >&2
    fi

    manifest_tmp="$($COREUTILS/mktemp "$set_root/vendor-manifest.json.vendor.XXXXXX")"
    if $JQ -n \
      --argjson specs "$specs_json" \
      --argjson versions "$versions_json" \
      --arg root "$set_root" '
      reduce ($specs[]) as $s (
        {};
        . + {($s.name): {
            source: ("npm:" + $s.spec),
            version: ($versions[$s.name]),
            path: ($root + "/node_modules/" + $s.name)
          }}
      )' > "$manifest_tmp" \
      && $JQ empty "$manifest_tmp" 2>/dev/null; then
      "$COREUTILS/mv" "$manifest_tmp" "$set_root/vendor-manifest.json"
    else
      "$COREUTILS/rm" -f "$manifest_tmp"
      echo "pi-npm-vendor: $base: could not write vendor manifest" >&2
    fi
  }

  # Publish the runtime settings.json: the Nix store settings (with
  # runtime-only user keys merged in from an existing file, Nix values
  # winning) and its npm package entries rewritten to the vendored set
  # paths. Object-form entries keep their filters; non-npm sources,
  # npmCommand, and every other settings key are preserved as declared.
  # Published only after the set verifies; atomic (mktemp + mv).
  publish_settings() {
    base="$1"
    settings_dir="$2"
    target_settings="$3"
    store_settings="$4"
    set_root="$5"
    specs_json="$6"

    vendored_json="$($JQ -c --arg root "$set_root" '
      reduce .[] as $s ({}; . + {($s.name): ($root + "/node_modules/" + $s.name)})
    ' <<<"$specs_json")"

    "$COREUTILS/mkdir" -p "$settings_dir"
    if [ -f "$target_settings" ]; then
      if ! $JQ empty "$target_settings" 2>/dev/null; then
        echo "pi-npm-vendor: $base: $target_settings is not valid JSON; refusing to publish" >&2
        return 1
      fi
    fi

    merge_stage="$($COREUTILS/mktemp "$settings_dir/.pi-npm-vendor-merge.XXXXXX")"
    publish_tmp="$($COREUTILS/mktemp "$settings_dir/.pi-npm-vendor.XXXXXX")"
    cleanup_stage() {
      "$COREUTILS/rm" -f "$merge_stage" "$publish_tmp"
    }

    if [ -f "$target_settings" ]; then
      $JQ -s '.[0] + .[1]' "$target_settings" "$store_settings" > "$merge_stage"
    else
      "$COREUTILS/cp" "$store_settings" "$merge_stage"
    fi

    if ! $JQ --argjson vendored "$vendored_json" '
      def npmname($s): ($s[4:] | split("@")) as $p | (if $p[0] == "" then "@" + $p[1] else $p[0] end);
      def withsource($e; $src):
        if ($e|type) == "string" then $src else $e + {source: $src} end;
      def rewrite($e):
        (if ($e|type) == "string" then $e else ($e.source // "") end) as $src
        | (if ($src|startswith("npm:")) then ($vendored[npmname($src)] // null) else null end) as $path
        | if $path == null then $e else withsource($e; $path) end;
      (if (.packages | type) == "array" then .packages |= map(rewrite(.)) else . end)
    ' "$merge_stage" > "$publish_tmp" 2>/dev/null; then
      cleanup_stage
      echo "pi-npm-vendor: $base: settings publish failed; previous settings preserved" >&2
      return 1
    fi
    "$COREUTILS/rm" -f "$merge_stage"
    if ! $JQ empty "$publish_tmp" 2>/dev/null; then
      cleanup_stage
      echo "pi-npm-vendor: $base: published settings failed validation; previous settings preserved" >&2
      return 1
    fi
    if [ -f "$target_settings" ] && "$CMP" -s "$target_settings" "$publish_tmp"; then
      "$COREUTILS/rm" -f "$publish_tmp"
      return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "pi-npm-vendor: $base: DRY-RUN would publish $target_settings from $set_root"
      "$COREUTILS/rm" -f "$publish_tmp"
      return 0
    fi
    "$COREUTILS/mv" "$publish_tmp" "$target_settings"
    "$COREUTILS/chmod" 0644 "$target_settings"
    echo "pi-npm-vendor: $base: published $target_settings with vendored package paths"
    return 0
  }

  vendor_base() {
    base="$1"
    store_settings="$2"
    settings_dir="$CONFIG_BASE/pi/bases/$base/settings"
    target_settings="$settings_dir/settings.json"

    specs_json="$($JQ -c "$SPEC_FIELDS" "$store_settings")"
    spec_count="$($JQ 'length' <<<"$specs_json")"
    set_root="$NPM_ROOT_BASE/$base/set-$(set_hash "$specs_json")"

    if [ "$spec_count" -eq 0 ]; then
      echo "pi-npm-vendor: $base: no npm packages declared"
    else
      incomplete() {
        while IFS=$'\t' read -r spec name version; do
          if ! spec_satisfied "$set_root" "$name" "$version"; then
            printf '%s\n' "$spec"
          fi
        done < <($JQ -r '.[] | "\(.spec)\t\(.name)\t\(.version)"' <<<"$specs_json")
      }

      if [ -n "$(incomplete)" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "pi-npm-vendor: $base: DRY-RUN would install missing packages into $set_root"
          echo "pi-npm-vendor: $base: DRY-RUN would verify and publish $target_settings"
          return 0
        fi
        # Batch the whole pinned set into the content-addressed root; the
        # previously published set (if any) stays untouched until this one
        # verifies, so failures preserve the last usable generation.
        if ! install_set "$base" "$set_root" \
          $($JQ -r '.[].spec' <<<"$specs_json"); then
          return 1
        fi
      fi

      unverified="$(incomplete)"
      if [ -n "$unverified" ]; then
        echo "pi-npm-vendor: $base: vendoring incomplete in $set_root:" >&2
        printf '  %s\n' $unverified >&2
        echo "pi-npm-vendor: $base: refusing to publish; previous settings preserved" >&2
        return 1
      fi

      if [ "$DRY_RUN" -eq 0 ]; then
        record_vendored_state "$base" "$set_root" "$specs_json"
      fi
      echo "pi-npm-vendor: $base: vendored $spec_count of $spec_count packages in $set_root"
    fi

    publish_settings "$base" "$settings_dir" "$target_settings" "$store_settings" "$set_root" "$specs_json" || return 1
  }

  if [ ! -r "$MANIFEST" ]; then
    echo "pi-npm-vendor: missing base manifest: $MANIFEST" >&2
    exit 1
  fi

  while IFS= read -r base; do
    store_settings="$($JQ -r --arg base "$base" '.[$base]' "$MANIFEST")"
    if ! vendor_base "$base" "$store_settings"; then
      FAILED_BASES="$FAILED_BASES $base"
    fi
  done < <($JQ -r 'keys[]' "$MANIFEST")

  if [ -n "$FAILED_BASES" ]; then
    echo "pi-npm-vendor: vendoring failed for:$FAILED_BASES" >&2
    echo "pi-npm-vendor: fix npm access or cache and rerun; no settings were downgraded" >&2
    exit 1
  fi

  echo "pi-npm-vendor: complete"
''
