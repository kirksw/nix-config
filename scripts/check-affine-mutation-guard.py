#!/usr/bin/env python3
"""Check AFFiNE mutation rejection without connecting to the server."""

from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parent.parent
runner = root / "agents/defs/skills/home-mcp/scripts/run.mjs"
env = os.environ.copy()
env.pop("MCP_WRITE_CONFIRMED", None)
for command in (
    "clear-doc-property", "compose-database-from-intent",
    "instantiate-template-native", "publish-doc", "read-all-notifications",
    "reparent-mindmap-node", "restore-doc", "sign-in", "trash-doc", "create-doc",
):
    result = subprocess.run(
        ["node", str(runner), "affine", command],
        capture_output=True, text=True, env=env, check=False,
    )
    assert result.returncode != 0, command
    assert "Refusing mutating affine command" in result.stderr, command
print("AFFiNE mutation guard: 10 checks passed")
