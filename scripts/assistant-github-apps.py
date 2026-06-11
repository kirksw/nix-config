#!/usr/bin/env python3
"""
Create and convert GitHub Apps for the assistant microVMs.

What this automates:
- Starts a localhost callback server.
- Serves buttons for the three assistant GitHub App manifests.
- Opens your browser to the local helper page.
- Receives GitHub's manifest callback code.
- Converts the code via GitHub's API.
- Saves the generated app metadata/private key outside the repo by default.

What GitHub still requires manually:
- Approving app creation in the browser.
- Installing each app on only its matching repository.

Default secret output:
  ~/.local/share/assistant-github-apps/<assistant>/

Do not commit generated *.secret.json or *.private-key.pem files.
"""

from __future__ import annotations

import argparse
import html
import http.server
import json
import os
import pathlib
import stat
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from dataclasses import dataclass
from typing import Any


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 9876
DEFAULT_OUTPUT_DIR = pathlib.Path.home() / ".local" / "share" / "assistant-github-apps"
WEBHOOK_PLACEHOLDER = "https://example.com/github-app-webhook-disabled"


@dataclass(frozen=True)
class AssistantApp:
    name: str
    repo: str


APPS = [
    AssistantApp("cntd-assistant-personal", "kirksw/kb-personal"),
    AssistantApp("cntd-assistant-household", "kirksw/kb-household"),
    AssistantApp("cntd-assistant-work", "kirksw/kb-lunar"),
]


def chmod_private(path: pathlib.Path) -> None:
    path.chmod(stat.S_IRUSR | stat.S_IWUSR)


def mkdir_private(path: pathlib.Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    path.chmod(stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)


def manifest_for(app: AssistantApp, base_url: str) -> dict[str, Any]:
    callback = f"{base_url}/github-app/callback/{urllib.parse.quote(app.name)}"
    return {
        "name": app.name,
        "url": f"https://github.com/{app.repo}",
        "hook_attributes": {
            "url": WEBHOOK_PLACEHOLDER,
            "active": False,
        },
        "redirect_url": callback,
        "callback_urls": [callback],
        "public": False,
        "default_permissions": {
            "contents": "read",
            "metadata": "read",
        },
        "default_events": [],
    }


def convert_manifest_code(code: str) -> dict[str, Any]:
    url = f"https://api.github.com/app-manifests/{urllib.parse.quote(code)}/conversions"
    request = urllib.request.Request(
        url,
        method="POST",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "assistant-github-apps-helper",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub conversion failed: HTTP {error.code}: {detail}") from error
    return json.loads(body)


def save_conversion(app_name: str, conversion: dict[str, Any], output_dir: pathlib.Path) -> pathlib.Path:
    app_dir = output_dir / app_name
    mkdir_private(output_dir)
    mkdir_private(app_dir)

    raw_path = app_dir / "github-app-conversion.secret.json"
    private_key_path = app_dir / "github-app.private-key.pem"
    metadata_path = app_dir / "github-app.metadata.json"
    env_path = app_dir / "github-app.env.template"

    raw_path.write_text(json.dumps(conversion, indent=2, sort_keys=True) + "\n")
    chmod_private(raw_path)

    pem = conversion.get("pem")
    if not isinstance(pem, str) or "PRIVATE KEY" not in pem:
        raise RuntimeError("GitHub conversion response did not contain a private key PEM")
    private_key_path.write_text(pem if pem.endswith("\n") else pem + "\n")
    chmod_private(private_key_path)

    redacted = dict(conversion)
    for key in ["pem", "webhook_secret", "client_secret"]:
        if key in redacted:
            redacted[key] = "<redacted>"
    metadata_path.write_text(json.dumps(redacted, indent=2, sort_keys=True) + "\n")
    chmod_private(metadata_path)

    app_id = conversion.get("id", "FILL_ME")
    env_path.write_text(
        "# Copy this into the matching microVM after installing the app and finding its installation ID.\n"
        f"GITHUB_APP_ID={app_id}\n"
        "GITHUB_INSTALLATION_ID=FILL_ME_AFTER_APP_INSTALL\n"
        "GITHUB_PRIVATE_KEY_FILE=/var/lib/openclaw/config/github-app-private-key.pem\n"
    )
    chmod_private(env_path)

    return app_dir


def render_index(base_url: str) -> bytes:
    sections = []
    for app in APPS:
        manifest = json.dumps(manifest_for(app, base_url), separators=(",", ":"))
        sections.append(
            f"""
            <section>
              <h2>{html.escape(app.name)}</h2>
              <p>Repository: <code>{html.escape(app.repo)}</code></p>
              <form action="https://github.com/settings/apps/new" method="post">
                <textarea name="manifest">{html.escape(manifest)}</textarea>
                <p><button type="submit">Create {html.escape(app.name)} app</button></p>
              </form>
            </section>
            """
        )

    page = f"""
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <title>Assistant GitHub App Manifests</title>
      <style>
        body {{ font-family: system-ui, sans-serif; max-width: 900px; margin: 2rem auto; line-height: 1.45; }}
        section {{ border: 1px solid #ddd; border-radius: 8px; padding: 1rem; margin: 1rem 0; }}
        button {{ font-size: 1rem; padding: 0.5rem 0.8rem; }}
        textarea {{ width: 100%; min-height: 9rem; font-family: ui-monospace, monospace; font-size: 0.9rem; }}
        code {{ background: #f5f5f5; padding: 0.1rem 0.25rem; }}
      </style>
    </head>
    <body>
      <h1>Assistant GitHub App Manifests</h1>
      <p>Click each button, approve creation in GitHub, then this local server will convert the returned manifest code.</p>
      <p>Permissions: <code>contents: read</code>, <code>metadata: read</code>. Webhooks are disabled.</p>
      {''.join(sections)}
    </body>
    </html>
    """
    return page.encode("utf-8")


def make_handler(output_dir: pathlib.Path, base_url: str):
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, fmt: str, *args: Any) -> None:
            print(f"[server] {fmt % args}")

        def send_html(self, status: int, body: str) -> None:
            encoded = body.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

        def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path in ["/", "/index.html"]:
                body = render_index(base_url)
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return

            prefix = "/github-app/callback/"
            if parsed.path.startswith(prefix):
                app_name = urllib.parse.unquote(parsed.path[len(prefix) :])
                params = urllib.parse.parse_qs(parsed.query)
                code = params.get("code", [None])[0]
                if not code:
                    self.send_html(400, "<h1>Missing code</h1><p>GitHub did not send a manifest code.</p>")
                    return
                try:
                    conversion = convert_manifest_code(code)
                    app_dir = save_conversion(app_name, conversion, output_dir)
                    slug = conversion.get("slug") or app_name
                    install_url = f"https://github.com/apps/{slug}/installations/new"
                except Exception as exc:  # noqa: BLE001 - show local helper error in browser
                    self.send_html(500, f"<h1>Conversion failed</h1><pre>{html.escape(str(exc))}</pre>")
                    return

                print(f"Converted {app_name}; saved credentials under {app_dir}")
                print(f"Install URL: {install_url}")
                self.send_html(
                    200,
                    f"""
                    <h1>Converted {html.escape(app_name)}</h1>
                    <p>Saved credentials under:</p>
                    <pre>{html.escape(str(app_dir))}</pre>
                    <p>Next: install this app on only its matching repository:</p>
                    <p><a href="{html.escape(install_url)}">{html.escape(install_url)}</a></p>
                    <p>After installation, record the installation ID in <code>github-app.env.template</code>.</p>
                    """,
                )
                return

            self.send_html(404, "<h1>Not found</h1>")

    return Handler


def serve(args: argparse.Namespace) -> None:
    base_url = f"http://{args.host}:{args.port}"
    output_dir = pathlib.Path(args.output_dir).expanduser().resolve()
    handler = make_handler(output_dir, base_url)
    server = http.server.ThreadingHTTPServer((args.host, args.port), handler)

    print(f"Serving GitHub App manifest helper at {base_url}")
    print(f"Secret output directory: {output_dir}")
    print("Press Ctrl-C when finished.")

    if args.open_browser:
        threading.Timer(0.5, lambda: webbrowser.open(base_url)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server.")
    finally:
        server.server_close()


def convert(args: argparse.Namespace) -> None:
    output_dir = pathlib.Path(args.output_dir).expanduser().resolve()
    conversion = convert_manifest_code(args.code)
    app_dir = save_conversion(args.app_name, conversion, output_dir)
    slug = conversion.get("slug") or args.app_name
    print(f"Converted {args.app_name}; saved credentials under {app_dir}")
    print(f"Install URL: https://github.com/apps/{slug}/installations/new")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command")

    serve_parser = subparsers.add_parser("serve", help="run local manifest/callback helper")
    serve_parser.add_argument("--host", default=DEFAULT_HOST)
    serve_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    serve_parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    serve_parser.add_argument("--no-open", action="store_false", dest="open_browser", help="do not open browser automatically")
    serve_parser.set_defaults(func=serve, open_browser=True)

    convert_parser = subparsers.add_parser("convert", help="convert an already-returned manifest code")
    convert_parser.add_argument("app_name", choices=[app.name for app in APPS])
    convert_parser.add_argument("code")
    convert_parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    convert_parser.set_defaults(func=convert)

    args = parser.parse_args(argv)
    if args.command is None:
        args = parser.parse_args(["serve", *argv])

    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
