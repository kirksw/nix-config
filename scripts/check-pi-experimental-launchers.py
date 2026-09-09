#!/usr/bin/env python3
"""Exercise Pi profile routing and pix without credentials or model calls."""

import os
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parent.parent / "modules/home/programs/ai-agents.nix").read_text()
start = source.index('          _pi_session_profile=')
end = source.index('          export PI_CODING_AGENT_DIR=', start)
selector = source[start:end].replace("''${", "${")
selector = 'is_lunar_project() { [[ "$PWD" == "$HOME/git/github.com/lunarway"* ]]; }\n' + selector
selector += '\nprintf "%s:%s\\n" "$_pi_session_profile" "$_pi_session_base"\n'
start = source.index('            set -euo pipefail', source.index('name = "pix"'))
end = source.index("          '';", start)
pix = source[start:end].replace("''${", "${")

with tempfile.TemporaryDirectory() as directory:
    directory = str(Path(directory).resolve())
    root = Path(directory)
    for name, body in {
        "pi": 'printf "%s\\n" "$NIX_AGENTS_PROFILE" "$@"',
        "fzf": 'cat > "$HOME/menu"; printf "default\\n"',
    }.items():
        stub = root / name
        stub.write_text(f'#!/bin/sh\n{body}\n')
        stub.chmod(0o755)
    env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=f"{directory}/config",
               PATH=f"{directory}:{os.environ['PATH']}")
    env.pop("NIX_AGENTS_PROFILE", None)
    env.pop("PI_CODING_AGENT_DIR", None)

    def run(script, environment, *args, cwd=root, code=0):
        result = subprocess.run(["bash", "-eu", "-c", script, "test", *args],
                                cwd=cwd, env=environment, text=True,
                                capture_output=True)
        assert result.returncode == code, result.stderr
        return result.stdout.strip()

    listing = run(pix, env, "list")
    assert all(name in listing for name in ("default", "fallback", "browser", "Google Hotels"))
    assert not (root / "menu").exists()
    assert "pix list" in run(pix, env, "--help")
    for bad in ("full", "factory", "experimental", "unknown", ""):
        run(pix, env, "--profile", bad, code=2)
    run(pix, env, "list", "extra", code=2)
    run(pix, env, "--scope", "invalid", code=2)
    run(pix, env, "--profile", code=2)
    assert run(pix, env) == "personal-default"
    assert (root / "menu").read_text().splitlines() == ["default", "fallback", "browser"]
    assert run(selector, env) == "personal-default:personal-default"

    for scope, cli_scope in (("personal", "home"), ("work", "work")):
        for kind in ("default", "fallback", "browser"):
            profile = f"{scope}-{kind}"
            base = scope if kind == "fallback" else profile
            child_env = env | {"PI_CODING_AGENT_DIR":
                f"{directory}/config/nix-agents/pi/bases/{base}/profiles/{profile}"}
            assert run(selector, child_env) == f"{profile}:{base}"
            assert run(selector, env | {"NIX_AGENTS_PROFILE": profile}) == f"{profile}:{base}"
            assert run(pix, env, "--profile", kind, "--scope", cli_scope) == profile
            assert run(pix, env | {"NIX_AGENTS_PROFILE": profile}, "--profile", kind) == profile
            assert run(pix, env, f"--profile={kind}", f"--scope={cli_scope}", "--", "list", "hello world") == f"{profile}\nlist\nhello world"
            (root / ".nix-agents-profile").write_text(profile)
            child = root / "child"
            child.mkdir(exist_ok=True)
            assert run(selector, env, cwd=child) == f"{profile}:{base}"
            assert run(pix, env, "--profile", kind, cwd=child) == profile
            (root / ".nix-agents-profile").unlink()
        print(f"{scope}: explicit, child, project, scope, and argument routing passed")
    work = root / "git/github.com/lunarway/project"
    work.mkdir(parents=True)
    assert run(selector, env, cwd=work) == "work-default:work-default"
    assert run(pix, env, "--profile", "browser", cwd=work) == "work-browser"
    for old in ("personal-full", "work-full", "home-factory", "personal-experimental"):
        run(selector, env | {"NIX_AGENTS_PROFILE": old}, code=2)
    print("list, help, menu, path defaults, and invalid selection checks passed")
