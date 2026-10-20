#!/usr/bin/env python3
"""Check synced minimal fallback, Herdr default, and browser settings without reading credentials."""

import json
import os
import re
from pathlib import Path

root = Path(os.environ["XDG_CONFIG_HOME"]) / "nix-agents"
bases = root / "pi/bases"
tintinweb = "npm:@tintinweb/pi-subagents@0.14.3"
herdr_agents = "local:pi-herdr-agents"
pi_extensions = "/Users/kisw/git/github.com/kirksw/pi-extensions/main"
plannotator = "npm:@plannotator/pi-extension"
agenticos = "/Users/kisw/git/github.com/kirksw/agenticOS/main"
excluded = {
    "npm:@juicesharp/rpiv-btw@1.20.0",
    "npm:context-mode@1.0.169",
    "npm:pi-observational-memory@3.0.3",
}


def identity(package):
    """Reduce a package reference to a stable name that ignores Nix store paths."""
    source = package["source"] if isinstance(package, dict) else package
    if source.startswith("npm:") or source == pi_extensions or source == agenticos:
        return source
    match = re.search(r"/agents/packages/([\w.-]+)$", source)
    if match:
        return f"local:{match.group(1)}"
    match = re.search(r"^[a-z0-9]{32}-(.+?)-\d[\w.-]*$", source.rsplit("/", 1)[-1])
    if match:
        return f"local:{match.group(1)}"
    return source


def identities(settings):
    return sorted(identity(package) for package in settings["packages"])


# Fallback profiles load only these packages; everything else is opt-in.
minimal = [
    "npm:pi-web-access@0.13.0",
    "npm:pi-verbosity-control@0.3.0",
    "local:pi-litellm-provider",
]
# Default and browser profiles keep the lean set with the Herdr replacement applied.
lean = [
    "npm:pi-cost@0.1.1",
    "local:pi-herdr",
    tintinweb,
    "npm:pi-observational-memory@3.0.3",
    "npm:pi-verbosity-control@0.3.0",
    "npm:pi-web-access@0.13.0",
    "npm:@juicesharp/rpiv-btw@1.20.0",
    "local:pi-todo",
]
herdr = sorted(
    [package for package in lean if package not in excluded and package != tintinweb]
    + [herdr_agents, pi_extensions, plannotator]
)

for scope in ("personal", "work"):
    fallback = bases / scope / "profiles" / f"{scope}-fallback"
    default = bases / f"{scope}-default/profiles/{scope}-default"
    browser = bases / f"{scope}-browser/profiles/{scope}-browser"
    fallback_settings = json.loads((fallback / "settings.json").read_text())
    default_settings = json.loads((default / "settings.json").read_text())
    assert identities(fallback_settings) == sorted(minimal), f"{scope}: unexpected fallback packages"
    assert "subagents" not in fallback_settings, f"{scope}: fallback keeps subagent settings"
    extra = [agenticos] if scope == "work" else ["local:pi-litellm-provider"]
    assert identities(default_settings) == sorted(herdr + extra), f"{scope}: unexpected default packages"
    assert tintinweb not in identities(default_settings), f"{scope}: default keeps Tintinweb"
    for profile in (fallback, default, browser):
        settings = json.loads((profile / "settings.json").read_text())
        deepseek = {"litellm/deepseek-flash", "litellm/deepseek-v4-pro"}
        if scope == "personal":
            assert deepseek <= set(settings["enabledModels"])
            manifest = (profile / "AGENTS.md").read_text()
            assert "openai-codex/" not in manifest
            assert "litellm/openai/gpt-6-astra" in manifest
            for agent in (profile / "agents").glob("*.md"):
                assert "model: openai-codex/" not in agent.read_text(), agent
        else:
            assert not deepseek.intersection(settings["enabledModels"])
    browser_settings = json.loads((browser / "settings.json").read_text())
    browser_extra = [] if scope == "work" else ["local:pi-litellm-provider"]
    assert identities(browser_settings) == sorted(herdr + browser_extra), f"{scope}: unexpected browser packages"
    assert "npm:pi-web-access@0.13.0" in identities(browser_settings)
    assert tintinweb not in identities(browser_settings)
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
    for skill in ("agent-browser", "google-hotels"):
        assert (browser / "skills" / skill / "SKILL.md").is_file(), (scope, skill)
    for profile in (fallback, default, browser):
        assert (profile / "skills/nix-config/SKILL.md").is_file(), (scope, profile)
        assert (profile / "skills/nix-config/recipes/manage-secrets.md").is_file(), (scope, profile)
        for retired in ("add-module", "nix-agents", "secrets-management", "system-context"):
            assert not (profile / "skills" / retired).exists(), (scope, profile, retired)
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
    print(f"{scope}: minimal fallback, Herdr default/browser, browser skills, isolated settings/auth verified")
