#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text
    raw = text[4:end]
    body = text[end + 5 :]
    meta: dict[str, str] = {}
    for line in raw.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        meta[key.strip()] = value.strip().strip('"')
    return meta, body


class PracticeCatalog:
    def __init__(self, skills_root: Path):
        self.skills_root = skills_root.resolve()
        self.skills = self._load_skills()

    def _safe_path(self, relative_path: str) -> Path:
        candidate = (self.skills_root / relative_path).resolve()
        if not candidate.is_relative_to(self.skills_root):
            raise ValueError("path escapes skills root")
        if not candidate.is_file():
            raise FileNotFoundError(relative_path)
        return candidate

    def _catalog_entries(self) -> dict[str, dict[str, Any]]:
        catalog_path = self.skills_root / "skill-catalog.json"
        if not catalog_path.is_file():
            return {}
        try:
            raw = json.loads(catalog_path.read_text())
        except (OSError, json.JSONDecodeError):
            return {}

        entries = raw.get("skills", raw)
        if isinstance(entries, list):
            result = {}
            for entry in entries:
                if isinstance(entry, dict) and isinstance(entry.get("name"), str):
                    result[entry["name"]] = entry
            return result
        if isinstance(entries, dict):
            return {name: entry for name, entry in entries.items() if isinstance(entry, dict)}
        return {}

    def _load_skills(self) -> dict[str, dict[str, Any]]:
        catalog = self._catalog_entries()
        skills: dict[str, dict[str, Any]] = {}
        if not self.skills_root.is_dir():
            return skills

        for skill_file in sorted(self.skills_root.glob("*/SKILL.md")):
            skill_dir = skill_file.parent
            name = skill_dir.name
            try:
                text = skill_file.read_text()
            except OSError:
                continue
            frontmatter, body = parse_frontmatter(text)
            heading = next((line.lstrip("# ").strip() for line in body.splitlines() if line.startswith("#")), name)
            description = (
                frontmatter.get("description")
                or str(catalog.get(name, {}).get("description", ""))
                or self._first_paragraph(body)
            )
            references = []
            references_dir = skill_dir / "references"
            if references_dir.is_dir():
                for ref in sorted(references_dir.rglob("*")):
                    if ref.is_file():
                        references.append(str(ref.relative_to(skill_dir)))
            scripts_dir = skill_dir / "scripts"
            scripts = []
            if scripts_dir.is_dir():
                for script in sorted(scripts_dir.rglob("*")):
                    if script.is_file():
                        scripts.append(str(script.relative_to(skill_dir)))

            skills[name] = {
                "name": name,
                "title": frontmatter.get("name") or heading,
                "description": description,
                "path": str(skill_file.relative_to(self.skills_root)),
                "references": references,
                "scripts": scripts,
                "catalog": catalog.get(name, {}),
            }
        return skills

    def _first_paragraph(self, text: str) -> str:
        lines = []
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                if lines:
                    break
                continue
            lines.append(stripped)
        return " ".join(lines)

    def list_skills(self) -> list[dict[str, Any]]:
        return [self._summary(skill) for skill in self.skills.values()]

    def search_skills(self, query: str) -> list[dict[str, Any]]:
        terms = [term.lower() for term in re.findall(r"\w+", query)]
        if not terms:
            return self.list_skills()

        matches = []
        for skill in self.skills.values():
            haystack_parts = [
                skill["name"],
                skill["title"],
                skill["description"],
                json.dumps(skill["catalog"], sort_keys=True),
            ]
            haystack = " ".join(haystack_parts).lower()
            score = sum(1 for term in terms if term in haystack)
            if score:
                item = self._summary(skill)
                item["score"] = score
                matches.append(item)
        return sorted(matches, key=lambda item: (-item["score"], item["name"]))

    def read_skill(self, name: str) -> str:
        skill = self._require_skill(name)
        return self._safe_path(skill["path"]).read_text()

    def read_reference(self, name: str, reference: str) -> str:
        skill = self._require_skill(name)
        if reference not in skill["references"] and reference not in skill["scripts"]:
            raise FileNotFoundError(f"{name}/{reference}")
        return self._safe_path(f"{name}/{reference}").read_text()

    def _require_skill(self, name: str) -> dict[str, Any]:
        if name not in self.skills:
            raise KeyError(name)
        return self.skills[name]

    def _summary(self, skill: dict[str, Any]) -> dict[str, Any]:
        return {
            "name": skill["name"],
            "title": skill["title"],
            "description": skill["description"],
            "references": skill["references"],
            "scripts": skill["scripts"],
        }


class McpServer:
    def __init__(self, catalog: PracticeCatalog):
        self.catalog = catalog

    def serve(self) -> None:
        for line in sys.stdin:
            if not line.strip():
                continue
            try:
                request = json.loads(line)
                response = self.handle(request)
            except Exception as exc:
                response = self.error(None, -32603, str(exc))
            if response is not None:
                sys.stdout.write(json.dumps(response, separators=(",", ":")) + "\n")
                sys.stdout.flush()

    def handle(self, request: dict[str, Any]) -> dict[str, Any] | None:
        method = request.get("method")
        request_id = request.get("id")
        if request_id is None:
            return None

        try:
            if method == "initialize":
                return self.result(
                    request_id,
                    {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "backend-practices-mcp", "version": "0.1.0"},
                    },
                )
            if method == "tools/list":
                return self.result(request_id, {"tools": self.tools()})
            if method == "tools/call":
                params = request.get("params", {})
                return self.result(request_id, self.call_tool(params.get("name"), params.get("arguments", {})))
            if method == "ping":
                return self.result(request_id, {})
            return self.error(request_id, -32601, f"unknown method: {method}")
        except (KeyError, FileNotFoundError, ValueError) as exc:
            return self.result(
                request_id,
                {"content": [{"type": "text", "text": str(exc)}], "isError": True},
            )

    def tools(self) -> list[dict[str, Any]]:
        return [
            {
                "name": "lunar_skills_list",
                "description": "List Lunar backend engineering practice skills available on demand.",
                "inputSchema": {"type": "object", "properties": {}},
            },
            {
                "name": "lunar_skills_search",
                "description": "Search backend engineering practice skills by topic before deciding what to load.",
                "inputSchema": {
                    "type": "object",
                    "required": ["query"],
                    "properties": {"query": {"type": "string"}},
                },
            },
            {
                "name": "lunar_skills_read",
                "description": "Read one backend engineering practice skill by name.",
                "inputSchema": {
                    "type": "object",
                    "required": ["name"],
                    "properties": {"name": {"type": "string"}},
                },
            },
            {
                "name": "lunar_skills_read_reference",
                "description": "Read a reference or script file for a backend engineering practice skill.",
                "inputSchema": {
                    "type": "object",
                    "required": ["name", "reference"],
                    "properties": {
                        "name": {"type": "string"},
                        "reference": {"type": "string"},
                    },
                },
            },
        ]

    def call_tool(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        if name == "lunar_skills_list":
            payload = self.catalog.list_skills()
        elif name == "lunar_skills_search":
            payload = self.catalog.search_skills(str(arguments.get("query", "")))
        elif name == "lunar_skills_read":
            return self.text_content(self.catalog.read_skill(str(arguments.get("name", ""))))
        elif name == "lunar_skills_read_reference":
            return self.text_content(
                self.catalog.read_reference(
                    str(arguments.get("name", "")),
                    str(arguments.get("reference", "")),
                )
            )
        else:
            raise KeyError(f"unknown tool: {name}")
        return self.text_content(json.dumps(payload, indent=2))

    def text_content(self, text: str) -> dict[str, Any]:
        return {"content": [{"type": "text", "text": text}]}

    def result(self, request_id: Any, result: dict[str, Any]) -> dict[str, Any]:
        return {"jsonrpc": "2.0", "id": request_id, "result": result}

    def error(self, request_id: Any, code: int, message: str) -> dict[str, Any]:
        return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skills-root", default=os.environ.get("BACKEND_PRACTICES_SKILLS_ROOT"))
    args = parser.parse_args()

    if not args.skills_root:
        raise SystemExit("--skills-root or BACKEND_PRACTICES_SKILLS_ROOT is required")

    McpServer(PracticeCatalog(Path(args.skills_root))).serve()


if __name__ == "__main__":
    main()
