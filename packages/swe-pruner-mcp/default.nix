{
  inputs,
  lib,
  stdenv,
  python3,
  writeShellScript,
  nix,
}:

let
  system = stdenv.hostPlatform.system;
  upstream = inputs.swe-pruner-mcp.packages.${system}.default;
in
upstream.overrideAttrs (old: {
  passthru =
    (old.passthru or { })
    // {
      updateScript = writeShellScript "update-swe-pruner-mcp" ''
        set -euo pipefail

        cd "$repo_root"
        ${lib.getExe nix} flake update swe-pruner-mcp
      '';
    };
  postPatch =
    (old.postPatch or "")
    + ''
      python_file=src/swe_pruner_mcp/server.py
      ${python3}/bin/python - "$python_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

text = text.replace(
    "from mcp.types import TextContent\n",
    "from mcp.types import TextContent, Tool\n",
)

old = """    @app.list_tools()
    async def list_tools() -> list[dict[str, Any]]:
        \"\"\"List available tools\"\"\"
        return [
            {
                \"name\": \"read_pruned\",
                \"description\": \"Read file contents with optional context-aware pruning based on a focus question. \"
                \"If no context_focus_question is provided, returns full content. \"
                \"If provided, returns only content relevant to the question, saving tokens.\",
                \"inputSchema\": {
                    \"type\": \"object\",
                    \"required\": [\"file_path\"],
                    \"properties\": {
                        \"file_path\": {
                            \"type\": \"string\",
                            \"description\": \"Path to the file to read\",
                        },
                        \"context_focus_question\": {
                            \"type\": \"string\",
                            \"description\": \"Optional question to guide pruning. \"
                            \"Only code relevant to this question will be returned. \"
                            \"If not provided, full file content is returned.\",
                        },
                    },
                },
            },
            {
                \"name\": \"search_pruned\",
                \"description\": \"Search codebase for a pattern with optional context-aware pruning. \"
                \"If no context_focus_question is provided, returns all matches. \"
                \"If provided, returns only matches relevant to the question.\",
                \"inputSchema\": {
                    \"type\": \"object\",
                    \"required\": [\"pattern\"],
                    \"properties\": {
                        \"pattern\": {
                            \"type\": \"string\",
                            \"description\": \"Pattern to search for (regex supported)\",
                        },
                        \"context_focus_question\": {
                            \"type\": \"string\",
                            \"description\": \"Optional question to guide pruning. \"
                            \"Only matches relevant to this question will be returned.\",
                        },
                    },
                },
            },
        ]
"""

new = """    @app.list_tools()
    async def list_tools() -> list[Tool]:
        \"\"\"List available tools\"\"\"
        return [
            Tool(
                name=\"read_pruned\",
                description=\"Read file contents with optional context-aware pruning based on a focus question. \"
                \"If no context_focus_question is provided, returns full content. \"
                \"If provided, returns only content relevant to the question, saving tokens.\",
                inputSchema={
                    \"type\": \"object\",
                    \"required\": [\"file_path\"],
                    \"properties\": {
                        \"file_path\": {
                            \"type\": \"string\",
                            \"description\": \"Path to the file to read\",
                        },
                        \"context_focus_question\": {
                            \"type\": \"string\",
                            \"description\": \"Optional question to guide pruning. \"
                            \"Only code relevant to this question will be returned. \"
                            \"If not provided, full file content is returned.\",
                        },
                    },
                },
            ),
            Tool(
                name=\"search_pruned\",
                description=\"Search codebase for a pattern with optional context-aware pruning. \"
                \"If no context_focus_question is provided, returns all matches. \"
                \"If provided, returns only matches relevant to the question.\",
                inputSchema={
                    \"type\": \"object\",
                    \"required\": [\"pattern\"],
                    \"properties\": {
                        \"pattern\": {
                            \"type\": \"string\",
                            \"description\": \"Pattern to search for (regex supported)\",
                        },
                        \"context_focus_question\": {
                            \"type\": \"string\",
                            \"description\": \"Optional question to guide pruning. \"
                            \"Only matches relevant to this question will be returned.\",
                        },
                    },
                },
            ),
        ]
"""

if old not in text:
    raise SystemExit("expected list_tools block not found in swe_pruner_mcp/server.py")

path.write_text(text.replace(old, new))
PY
    '';
})
