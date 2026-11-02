#!/usr/bin/env bash
# Offline npm stand-in for sandboxed checks and tests: materializes the
# packages named by `install <spec...> --prefix <root> --legacy-peer-deps`
# instead of hitting a registry. Versions come from the pinned specs
# (0.0.0-stub when unpinned), which is what pi-npm-vendor verifies.
set -euo pipefail

# PI_NPM_CALL_LOG, when set, receives each invocation's arguments (test
# hook; production callers leave it unset).
if [ -n "${PI_NPM_CALL_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$PI_NPM_CALL_LOG"
fi

# FAIL_NEXT_INSTALL=1 makes the next invocation exit 1 like a registry
# failure (test hook; production callers never set it).
if [ -n "${FAIL_NEXT_INSTALL:-}" ]; then
  echo "pi-npm-stub: simulated registry failure" >&2
  exit 1
fi

root=""
expect_root=0
specs=()
for arg in "$@"; do
  case "$arg" in
    install|--legacy-peer-deps) ;;
    --prefix) expect_root=1 ;;
    *)
      if [ "$expect_root" = 1 ]; then
        root="$arg"
        expect_root=0
      else
        specs+=("$arg")
      fi
      ;;
  esac
done

mkdir -p "$root/node_modules"
for spec in "${specs[@]}"; do
  version="0.0.0-stub"
  case "$spec" in
    @*)
      rest="${spec#@}"
      case "$rest" in
        *@*)
          name="@${rest%%@*}"
          version="${rest##*@}"
          ;;
        *) name="@$rest" ;;
      esac
      ;;
    *@*)
      name="${spec%%@*}"
      version="${spec##*@}"
      ;;
    *) name="$spec" ;;
  esac
  dir="$root/node_modules/$name"
  mkdir -p "$dir"
  printf '{"name":"%s","version":"%s"}\n' "$name" "$version" > "$dir/package.json"
done
