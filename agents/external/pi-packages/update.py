#!/usr/bin/env python3
"""Check and update pi extension versions in registry.nix from npm and git upstreams."""

import json
import re
import subprocess
import sys
from pathlib import Path


def parse_registry(path: Path) -> list[dict]:
    """Parse registry.nix into a list of package entries."""
    text = path.read_text()
    entries = []
    # Match blocks: "key" = { ... }; or key = { ... };
    for m in re.finditer(r'"?([\w-]+)"?\s*=\s*\{([^}]+)\}', text):
        key, body = m.group(1), m.group(2)
        entry = {"key": key}

        npm_match = re.search(r'npmName\s*=\s*"([^"]+)"', body)
        if npm_match:
            entry["npmName"] = npm_match.group(1)

        version_match = re.search(r'version\s*=\s*"([^"]+)"', body)
        if version_match:
            entry["version"] = version_match.group(1)

        ref_match = re.search(r'ref\s*=\s*"git:([^@]+)@([0-9a-f]+)"', body)
        if ref_match:
            entry["git_repo"] = ref_match.group(1)
            entry["git_commit"] = ref_match.group(2)

        if "npmName" in entry or "git_repo" in entry:
            entries.append(entry)

    return entries


def get_npm_latest(npm_name: str) -> str | None:
    try:
        result = subprocess.run(
            ["npm", "view", npm_name, "version"],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None


def get_git_latest_commit(repo: str) -> str | None:
    # repo is like "github.com/owner/repo"
    url = f"https://{repo}"
    try:
        result = subprocess.run(
            ["git", "ls-remote", url, "HEAD"],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode == 0 and result.stdout:
            return result.stdout.split("\t")[0].strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None


def update_registry_version(path: Path, key: str, old: str, new: str) -> None:
    """Replace old version string with new within the key's block."""
    text = path.read_text()
    # For npm: update the version = "..." line within the block
    # For git: update both ref and version lines
    pattern = rf'("{re.escape(key)}"\s*=\s*\{{[^}}]*?)\b{re.escape(old)}\b'
    text_new = re.sub(pattern, lambda m: m.group(1) + new, text, count=1, flags=re.DOTALL)
    # For git packages, the commit appears in both ref and version — replace all occurrences in the block
    if old != new:
        path.write_text(text_new)


def main():
    # Find registry.nix relative to the git repo root
    try:
        root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        registry = Path(root) / "agents/external/pi-packages/registry.nix"
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Fall back to script directory (for local dev)
        script_dir = Path(__file__).resolve().parent
        registry = script_dir / "registry.nix"

    if not registry.exists():
        print(f"registry.nix not found", file=sys.stderr)
        sys.exit(1)

    entries = parse_registry(registry)
    if not entries:
        print("No packages found in registry.nix")
        sys.exit(0)

    print("Checking pi extension versions...\n")

    updated = 0

    for entry in entries:
        key = entry["key"]

        if "npmName" in entry:
            npm_name = entry["npmName"]
            current = entry["version"]
            latest = get_npm_latest(npm_name)

            if latest is None:
                print(f"  {key:<20} {current:<12} (lookup failed)")
            elif current == latest:
                print(f"  {key:<20} {current:<12} ✓")
            else:
                print(f"  {key:<20} {current:<12} → {latest}  updating")
                # Replace version within this key's block
                text = registry.read_text()
                old_line = f'version = "{current}";'
                new_line = f'version = "{latest}";'
                # Find the block and replace within it
                block_pattern = rf'("?{re.escape(key)}"?\s*=\s*\{{[^}}]*?{re.escape(old_line)})'
                text = re.sub(block_pattern, lambda m: m.group(1).replace(old_line, new_line), text, flags=re.DOTALL)
                registry.write_text(text)
                updated += 1

        elif "git_repo" in entry:
            repo = entry["git_repo"]
            current = entry["git_commit"]
            latest = get_git_latest_commit(repo)

            if latest is None or not latest:
                print(f"  {key:<20} {current[:8]:<12} (lookup failed)")
            elif current == latest:
                print(f"  {key:<20} {current[:8]:<12} ✓")
            else:
                latest_commit: str = latest
                print(f"  {key:<20} {current[:8]:<12} → {latest_commit[:8]}  updating")
                # Replace old commit with new in both ref and version within this key's block
                text = registry.read_text()
                block_pattern = rf'("?{re.escape(key)}"?\s*=\s*\{{[^}}]*?{re.escape(current)}.*?\}};)'
                def _replace_git(m):
                    return m.group(0).replace(current, latest_commit)
                text = re.sub(block_pattern, _replace_git, text, count=1, flags=re.DOTALL)
                registry.write_text(text)
                updated += 1

    print()
    if updated == 0:
        print("All extensions are up to date.")
    else:
        print(f"{updated} extension(s) updated in registry.nix")
        print()
        print("Next steps:")
        print("  1. Review changes:  git diff agents/external/pi-packages/registry.nix")
        print("  2. Apply locally:   nix run .#sync-agents")
        print("  3. Or system wide:  nix run .#switch")


if __name__ == "__main__":
    main()
