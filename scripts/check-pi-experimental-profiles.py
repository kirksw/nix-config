#!/usr/bin/env python3
"""Check synced Pi fallback, default, browser, and web profiles without reading credentials."""

import json
import os
import re
from pathlib import Path

root = Path(os.environ["XDG_CONFIG_HOME"]) / "nix-agents"
bases = root / "pi/bases"
tintinweb = "npm:@tintinweb/pi-subagents"
herdr_agents = "local:pi-herdr-agents"
pi_extensions = "/Users/kisw/git/github.com/kirksw/pi-extensions/main"
agenticos = "/Users/kisw/git/github.com/kirksw/agenticOS/main"
plannotator = "npm:@plannotator/pi-extension"
lunar = [
    "npm:@lunarway/pi-lunar-quiet-tools",
    "npm:@lunarway/pi-lunar-litellm",
    "npm:@lunarway/pi-lunar-statusline",
]
context_decisions = "npm:pi-context-decisions"
excluded = {
    "npm:@juicesharp/rpiv-btw",
    "npm:context-mode",
    "npm:pi-observational-memory",
}
# Exact pins that vendored copies and npm sources must both carry.
# @plannotator/pi-extension is deliberately unpinned.
pins = {
    "pi-verbosity-control": "0.3.0",
    "pi-web-access": "0.13.0",
    "pi-claude-bridge": "0.9.3",
    "@lunarway/pi-lunar-quiet-tools": "0.1.0",
    "@lunarway/pi-lunar-litellm": "0.2.1",
    "@lunarway/pi-lunar-statusline": "0.7.0",
    "pi-context-decisions": "2.2.0",
    "@tintinweb/pi-subagents": "0.14.3",
}
vendored_re = re.compile(
    r"^(?P<root>.*/pi/npm/(?P<base>[^/]+)(?:/set-[0-9a-f]+)?)/node_modules/(?P<name>@[^/]+/[^/]+|[^/]+)$"
)


def npm_name(source):
    """Reduce an npm source or vendored path to its package name."""
    match = vendored_re.match(source)
    if match:
        return match.group("name")
    if source.startswith("npm:"):
        spec = source[len("npm:") :]
        parts = spec.split("@")
        return "@" + parts[1] if parts[0] == "" else parts[0]
    return None


def vendored_version(source):
    """Installed version of a vendored package path, or None."""
    match = vendored_re.match(source)
    if not match:
        return None
    pkg = Path(match.group("root")) / "node_modules" / match.group("name") / "package.json"
    if not pkg.is_file():
        return None
    return json.loads(pkg.read_text()).get("version")


def identity(package):
    """Reduce a package reference to a stable name that ignores Nix store paths."""
    source = package["source"] if isinstance(package, dict) else package
    name = npm_name(source)
    if name is not None:
        return f"npm:{name}"
    match = re.search(r"/agents/packages/([\w.-]+)$", source)
    if match:
        return f"local:{match.group(1)}"
    match = re.search(r"^[a-z0-9]{32}-(.+?)-\d[\w.-]*$", source.rsplit("/", 1)[-1])
    if match:
        return f"local:{match.group(1)}"
    return source


def identities(settings):
    return sorted(identity(package) for package in settings["packages"])


def check_pins(scope, base, settings):
    """Vendored copies and npm sources must both carry the pinned versions."""
    for package in settings["packages"]:
        source = package["source"] if isinstance(package, dict) else package
        name = npm_name(source)
        if name is None or name not in pins:
            continue
        expected = pins[name]
        match = vendored_re.match(source)
        if match:
            assert match.group("base") == base, f"{scope}: {source} vendored under the wrong base"
            actual = vendored_version(source)
            assert actual == expected, f"{scope}: {name} vendored as {actual}, expected {expected}"
        else:
            spec = source[len("npm:") :]
            parts = spec.split("@")
            version = parts[-1] if len(parts) > (1 if parts[0] else 2) else None
            assert version == expected, f"{scope}: {source} does not pin {expected}"


# Fallback profiles load only these packages; everything else is opt-in.
minimal = [
    "npm:pi-web-access",
    "npm:pi-verbosity-control",
    "local:pi-litellm-provider",
]
# Default and browser profiles keep the lean set with the Herdr replacement applied.
lean = [
    "local:pi-herdr",
    tintinweb,
    "npm:pi-observational-memory",
    "npm:pi-verbosity-control",
    "npm:pi-web-access",
    "npm:@juicesharp/rpiv-btw",
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
    web = bases / f"{scope}-web/profiles/{scope}-web"
    fallback_settings = json.loads((fallback / "settings.json").read_text())
    default_settings = json.loads((default / "settings.json").read_text())
    fallback_packages = (
        [*minimal[:-1], "npm:@lunarway/pi-lunar-litellm"]
        if scope == "work"
        else [*minimal, "npm:pi-claude-bridge"]
    )
    assert identities(fallback_settings) == sorted(fallback_packages), f"{scope}: unexpected fallback packages"
    assert "subagents" not in fallback_settings, f"{scope}: fallback keeps subagent settings"
    extra = (
        [agenticos, *lunar, context_decisions]
        if scope == "work"
        else ["local:pi-litellm-provider", "npm:pi-claude-bridge"]
    )
    assert identities(default_settings) == sorted(herdr + extra), f"{scope}: unexpected default packages"
    assert tintinweb not in identities(default_settings), f"{scope}: default keeps Tintinweb"
    for profile in (fallback, default, browser, web):
        settings = json.loads((profile / "settings.json").read_text())
        base_dir = profile.parent.parent.name
        check_pins(scope, base_dir, settings)
        for package in settings["packages"]:
            source = package["source"] if isinstance(package, dict) else package
            assert not source.startswith("npm:"), (
                f"{scope}: {source} would trigger a startup npm install"
            )
        deepseek = {"litellm/deepseek-flash", "litellm/deepseek-v4-pro"}
        if scope == "personal":
            assert deepseek <= set(settings["enabledModels"])
            assert "claude-bridge/*" in settings["enabledModels"]
            assert json.loads((profile / "models.json").read_text())["providers"] == {}
            manifest = (profile / "AGENTS.md").read_text()
            assert "openai-codex/" not in manifest
            assert "litellm/openai/gpt-6-astra" in manifest
            for agent in (profile / "agents").glob("*.md"):
                assert "model: openai-codex/" not in agent.read_text(), agent
        else:
            assert not deepseek.intersection(settings["enabledModels"])
            assert settings["defaultProvider"] == "lunar"
            assert settings["enabledModels"] == ["lunar/*"]
            assert "openai" not in json.loads((profile / "models.json").read_text())["providers"]
            assert "openai" not in json.loads((profile / "auth.json").read_text())
    web_settings = json.loads((web / "settings.json").read_text())
    assert identities(web_settings) == identities(default_settings), f"{scope}: unexpected web packages"
    for skill in (
        "animate", "animate-expo", "animation-performance", "animation-vocabulary",
        "apple-design", "ask-sonner", "break-ui", "emil-design-eng",
        "find-animation-opportunities", "improve-animations", "mobile-native",
        "pick-ui-library", "prototype", "remove-animations", "review-animations",
        "write-swift", "impeccable", "design-taste-frontend",
    ):
        assert (web / "skills" / skill / "SKILL.md").is_file(), (scope, skill)
        assert not (default / "skills" / skill).exists(), (scope, skill)
    assert (web / "skills/impeccable/reference/craft-floor.md").is_file()
    assert (web / "skills/design-taste-frontend/scripts/draw.mjs").is_file()
    assert (web / "skills/animate/RECIPES.md").is_file()
    browser_settings = json.loads((browser / "settings.json").read_text())
    browser_extra = (
        [*lunar, context_decisions]
        if scope == "work"
        else ["local:pi-litellm-provider", "npm:pi-claude-bridge"]
    )
    assert identities(browser_settings) == sorted(herdr + browser_extra), f"{scope}: unexpected browser packages"
    assert "npm:pi-web-access" in identities(browser_settings)
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
    if scope == "work":
        assert not (default / "skills/work-mcp").exists()
        for skill in ("1password", "grafana", "granola", "hubble-mcp", "linear", "lunar-skills", "slack", "sourcegraph"):
            assert (default / "skills" / skill / "scripts/run.mjs").is_file(), skill
    for skill in ("agent-browser", "google-hotels"):
        assert (browser / "skills" / skill / "SKILL.md").is_file(), (scope, skill)
    for profile in (fallback, default, browser, web):
        assert (profile / "skills/nix-config/SKILL.md").is_file(), (scope, profile)
        assert (profile / "skills/nix-config/recipes/manage-secrets.md").is_file(), (scope, profile)
        for retired in ("add-module", "nix-agents", "secrets-management", "system-context"):
            assert not (profile / "skills" / retired).exists(), (scope, profile, retired)
    for name in ("models.json", "mcporter.json"):
        assert json.loads((fallback / name).read_text()) == json.loads((default / name).read_text())
    for profile in (default, browser, web):
        auth = profile / "auth.json"
        assert auth.is_symlink()
        fallback_auth = bases / scope / "settings/auth.json"
        if not fallback_auth.is_file():
            fallback_auth = bases / scope / "state/auth.json"
        assert auth.resolve() == fallback_auth.resolve(), f"{scope}: wrong auth scope"
        assert (profile / "settings.json").resolve() != (fallback / "settings.json").resolve()
    for removed in (f"{scope}-full", f"{scope}-experimental", "home-factory", "work-factory"):
        assert not (bases / removed).exists(), removed
    print(f"{scope}: fallback, Herdr default/browser/web, pinned web skills, isolated settings/auth verified")
