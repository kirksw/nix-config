#!/usr/bin/env bash
set -euo pipefail

fail=0

err() {
  echo "ERROR: $*" >&2
  fail=1
}

for domain in home darwin nixos shared; do
  if [[ ! -f "modules/${domain}/imports.nix" ]]; then
    err "Missing modules/${domain}/imports.nix"
  fi

done

for domain in home darwin nixos shared; do
  if rg -n "listFilesRecursive" "modules/${domain}/default.nix" >/dev/null; then
    err "Recursive auto-import is not allowed in modules/${domain}/default.nix"
  fi

  if ! rg -n "imports\s*=\s*import\s+\./imports\.nix;" "modules/${domain}/default.nix" >/dev/null; then
    err "modules/${domain}/default.nix must import ./imports.nix"
  fi

done

manifest_entries() {
  local manifest="$1"
  rg -No '\./[^" ]+\.nix' "$manifest" || true
}

check_manifest_sorted() {
  local domain="$1"
  local manifest="modules/${domain}/imports.nix"
  local entries
  entries="$(manifest_entries "$manifest")"
  if [[ -n "$entries" ]] && ! diff -u <(printf "%s\n" "$entries") <(printf "%s\n" "$entries" | sort) >/dev/null; then
    err "modules/${domain}/imports.nix must be sorted lexicographically"
  fi
}

check_manifest_paths_exist() {
  local domain="$1"
  local manifest="modules/${domain}/imports.nix"
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    local path="modules/${domain}/${entry#./}"
    if [[ ! -f "$path" ]]; then
      err "modules/${domain}/imports.nix references missing file: ${entry}"
    fi
  done < <(manifest_entries "$manifest")
}

check_manifest_covers_modules() {
  local domain="$1"
  shift
  local expected=("$@")
  local manifest="modules/${domain}/imports.nix"

  for rel in "${expected[@]}"; do
    if ! rg -n "^[[:space:]]*\\./${rel}$" "$manifest" >/dev/null; then
      err "modules/${domain}/imports.nix is missing: ./${rel}"
    fi
  done
}

check_manifest_domain() {
  local domain="$1"
  shift
  local folders=("$@")
  local expected=()

  for folder in "${folders[@]}"; do
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      expected+=("${folder}/$(basename "$file")")
    done < <(find "modules/${domain}/${folder}" -maxdepth 1 -type f -name '*.nix' ! -name 'default.nix' ! -name 'template.nix' ! -name 'imports.nix' | sort)
  done

  check_manifest_sorted "$domain"
  check_manifest_paths_exist "$domain"
  check_manifest_covers_modules "$domain" "${expected[@]}"
}

check_manifest_shared() {
  local domain="shared"
  local expected=()

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    expected+=("$(basename "$file")")
  done < <(find "modules/shared" -maxdepth 1 -type f -name '*.nix' ! -name 'default.nix' ! -name 'template.nix' ! -name 'imports.nix' | sort)

  check_manifest_sorted "$domain"
  check_manifest_paths_exist "$domain"
  check_manifest_covers_modules "$domain" "${expected[@]}"
}

check_manifest_domain "home" "programs" "services"
check_manifest_domain "darwin" "programs" "services"
check_manifest_domain "nixos" "generic"
check_manifest_shared

if rg -n "^[[:space:]]+[a-zA-Z0-9_-]+\\.enable = lib\\.mkEnableOption" modules/home >/dev/null; then
  err "Home modules must define option toggles under homeModules.<name>.enable"
fi

if rg -n "^[[:space:]]+[a-zA-Z0-9_-]+\\.enable = lib\\.mkEnableOption" modules/darwin >/dev/null; then
  err "Darwin modules must define option toggles under darwinModules.<name>.enable"
fi

if rg -n "options\\.my\\.|config\\.my\\." modules/nixos >/dev/null; then
  err "NixOS modules must use nixosModules.<name> namespace"
fi

if rg -n "homeModules\\.[a-z]+dev\\.enable" modules hosts >/dev/null; then
  err "Use camelCase for multi-word home module options (example: homeModules.aiDev.enable)"
fi

if rg -n "nixpkgs\s*=\s*\{[[:space:][:print:]]*overlays" modules/shared >/dev/null; then
  err "Shared modules must not set overlays; overlays are assembled in flake/overlays.nix"
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "Structure checks passed."
