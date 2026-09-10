#!/usr/bin/env python3
"""Check synced default, fallback, and browser settings without reading credentials."""

import json
import os
from pathlib import Path

root = Path(os.environ["XDG_CONFIG_HOME"]) / "nix-agents"
bases = root / "pi/bases"
old = "npm:@tintinweb/pi-subagents@0.14.3"
new = "npm:pi-herdr-agents@1.5.1"

for scope in ("personal", "work"):
    fallback = bases / scope / "profiles" / f"{scope}-fallback"
    default = bases / f"{scope}-default/profiles/{scope}-default"
    browser = bases / f"{scope}-browser/profiles/{scope}-browser"
    baseline = json.loads((fallback / "settings.json").read_text())
    actual = json.loads((default / "settings.json").read_text())
    assert baseline["packages"].count(old) == 1
    assert new not in baseline["packages"]
    excluded = {
        "npm:@juicesharp/rpiv-btw@1.20.0",
        "npm:context-mode@1.0.169",
        "npm:pi-observational-memory@3.0.3",
    }
    expected = baseline | {"packages": [
        new if p == old else p for p in baseline["packages"]
        if (p["source"] if isinstance(p, dict) else p) not in excluded
    ] + ["/Users/kisw/git/github.com/kirksw/pi-extensions/main"]}
    assert actual == expected, f"{scope}: unexpected default settings"
    browser_settings = json.loads((browser / "settings.json").read_text())
    assert "npm:pi-web-access@0.13.0" in browser_settings["packages"]
    assert new not in browser_settings["packages"]
    servers = json.loads((browser / "mcporter.json").read_text())["mcpServers"]
    if scope == "personal":
        assert set(servers) == {"affine"}
        assert servers["affine"]["url"] == "http://nixos-ry6a.tail54de03.ts.net:31410/mcp"
        assert servers["affine"]["headers"] == {"Authorization": "Bearer ${AFFINE_MCP_HTTP_TOKEN}"}
        assert servers["affine"]["lifecycle"] == "ephemeral"
        for skill in ("home-mcp", "affine"):
            assert (browser / "skills" / skill / "SKILL.md").is_file()
    else:
        assert servers == {}
        assert not (browser / "skills/affine").exists()
    for profile in (fallback, default):
        assert not (profile / "skills/affine").exists()
        assert "affine" not in json.loads((profile / "mcporter.json").read_text())["mcpServers"]
    for skill in ("agent-browser", "google-hotels", "system-context"):
        assert (browser / "skills" / skill / "SKILL.md").is_file(), (scope, skill)
    for name in ("models.json", "mcporter.json"):
        assert json.loads((fallback / name).read_text()) == json.loads((default / name).read_text())
    for profile in (default, browser):
        auth = profile / "auth.json"
        assert auth.is_symlink()
        fallback_auth = bases / scope / "settings/auth.json"
        if not fallback_auth.is_file():
            fallback_auth = bases / scope / "state/auth.json"
        assert auth.resolve() == fallback_auth.resolve(), f"{scope}: wrong auth scope"
        assert (profile / "settings.json").resolve() != (fallback / "settings.json").resolve()
    for removed in (f"{scope}-full", f"{scope}-experimental", "home-factory", "work-factory"):
        assert not (bases / removed).exists(), removed
    for target in ("claude", "codex", "opencode"):
        for kind in ("fallback", "browser"):
            assert not (root / target / "bases" / f"{scope}-{kind}").exists()
    print(f"{scope}: promoted default, independent fallback, browser skills, isolated settings/auth verified")
