#!/usr/bin/env python3
"""Small stdio-to-HTTP MCP bridge for the Google Drive MCP endpoint."""

import json
import signal
import subprocess
import sys
import urllib.error
import urllib.request

ENDPOINT = "https://drivemcp.googleapis.com/mcp/v1"
REQUEST_TIMEOUT_SECONDS = 30
MAX_RESPONSE_BYTES = 10 * 1024 * 1024
_session_id = None
_protocol_version = None
_initialize_request = None
_last_http_status = None
_stopping = False


class _NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Never follow redirects, which could leak Authorization cross-origin."""

    def redirect_request(self, _request, _response, _code, _msg, _headers, _newurl):
        return None


_NO_REDIRECT_OPENER = urllib.request.build_opener(_NoRedirectHandler())
# Keep the network operation behind a small injectable seam for tests.
_open = _NO_REDIRECT_OPENER.open


def _diagnostic(message):
    print(f"google-drive-mcp-auth: {message}", file=sys.stderr)


def _token():
    # Do not include stdout/stderr in diagnostics: either could contain a token.
    result = subprocess.run(
        ["gcloud", "auth", "print-access-token"],
        check=True,
        capture_output=True,
        text=True,
    )
    token = result.stdout.strip()
    if not token:
        raise RuntimeError("gcloud returned an empty access token")
    return token


def _jsonrpc_error(request, message):
    return {"jsonrpc": "2.0", "id": request.get("id"), "error": {"code": -32603, "message": message}}


def _parse_body(body, content_type):
    """Return JSON messages from an ordinary or one complete SSE response."""
    if "text/event-stream" not in content_type.lower():
        return [json.loads(body)]

    messages = []
    data = []

    def finish_event():
        if not data:
            return
        payload = "\n".join(data)
        data.clear()
        if payload and payload != "[DONE]":
            messages.append(json.loads(payload))

    for line in body.splitlines():
        # SSE comments and fields other than data are not part of the JSON.
        if line.startswith("data:"):
            data.append(line[5:].lstrip())
        elif line.strip() == "":
            finish_event()
    finish_event()
    return messages


def _read_body(response, content_type):
    """Read a bounded response without waiting forever for an SSE stream to close."""
    if "text/event-stream" in content_type.lower():
        chunks = []
        size = 0
        saw_data = False
        while True:
            line = response.readline()
            if not line:
                break
            size += len(line)
            if size > MAX_RESPONSE_BYTES:
                raise ValueError("upstream response exceeded size limit")
            chunks.append(line)
            if line.startswith(b"data:"):
                saw_data = True
            # This bridge supports one complete SSE response per request.
            if saw_data and line.strip() == b"":
                break
        return b"".join(chunks).decode("utf-8")

    body = response.read(MAX_RESPONSE_BYTES + 1)
    if len(body) > MAX_RESPONSE_BYTES:
        raise ValueError("upstream response exceeded size limit")
    return body.decode("utf-8")


def _is_successful_initialize_response(request, response):
    """Only a valid initialize result can authorize unsolicited recovery."""
    if len(response) != 1 or not isinstance(response[0], dict):
        return False
    message = response[0]
    return (
        message.get("jsonrpc") == "2.0"
        and message.get("id") == request.get("id")
        and isinstance(message.get("result"), dict)
    )


def _forward_once(request):
    global _last_http_status, _protocol_version, _session_id
    _last_http_status = None
    is_initialize = request.get("method") == "initialize"
    initialize_protocol = None
    if is_initialize:
        # A new initialize starts a new MCP session. Do this before building
        # headers so a stale session id is never sent with initialize.
        _session_id = None
        _protocol_version = None
        params = request.get("params")
        if isinstance(params, dict) and isinstance(params.get("protocolVersion"), str):
            initialize_protocol = params["protocolVersion"]

    try:
        token = _token()
    except (subprocess.CalledProcessError, OSError):
        _diagnostic("gcloud could not provide an access token")
        return [_jsonrpc_error(request, "gcloud authentication failed")]
    except RuntimeError as error:
        _diagnostic(str(error))
        return [_jsonrpc_error(request, "gcloud authentication failed")]

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    # MCP-Protocol-Version is required after initialize, not on initialize itself.
    if _protocol_version and not is_initialize:
        headers["MCP-Protocol-Version"] = _protocol_version
    if _session_id and not is_initialize:
        headers["mcp-session-id"] = _session_id
    payload = json.dumps(request, separators=(",", ":")).encode("utf-8")
    http_request = urllib.request.Request(ENDPOINT, data=payload, headers=headers, method="POST")
    try:
        with _open(http_request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            session = response.headers.get("mcp-session-id")
            content_type = response.headers.get("content-type", "application/json")
            body = _read_body(response, content_type)
            parsed = _parse_body(body, content_type)
            # Do not make an invalid/failed initialize usable for recovery.
            if is_initialize:
                if _is_successful_initialize_response(request, parsed):
                    _protocol_version = initialize_protocol
                    if session:
                        _session_id = session
            elif session:
                _session_id = session
            return parsed
    except urllib.error.HTTPError as error:
        _last_http_status = error.code
        if error.code == 404:
            _session_id = None
        # The preview endpoint can return a valid JSON-RPC body with an HTTP
        # error status (observed: HTTP 403 carrying a complete tools/list
        # result). Pass such bodies through instead of discarding them.
        # Never print the upstream body: it can echo request or credential material.
        try:
            content_type = error.headers.get("content-type", "application/json")
            parsed = _parse_body(_read_body(error, content_type), content_type)
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            _diagnostic(f"upstream HTTP {error.code}")
            return [_jsonrpc_error(request, f"Google Drive MCP returned HTTP {error.code}")]
        _diagnostic(f"upstream HTTP {error.code} with a valid response body")
        return parsed
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
        _diagnostic(f"upstream response failed: {type(error).__name__}")
        return [_jsonrpc_error(request, "Google Drive MCP returned an invalid response")]
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        _diagnostic(f"upstream request failed: {type(error).__name__}")
        return [_jsonrpc_error(request, "Google Drive MCP request failed")]


def forward(request):
    global _initialize_request
    is_initialize = request.get("method") == "initialize"
    if is_initialize:
        response = _forward_once(request)
        if _is_successful_initialize_response(request, response):
            # Keep a copy so session recovery can use a fresh token and avoid
            # mutating the caller's request while retrying.
            _initialize_request = json.loads(json.dumps(request))
        else:
            _initialize_request = None
        return response

    # Recovery is safe only when this exact request carried the cached session
    # header and the MCP protocol's invalid-session status (404) was returned.
    sent_session = bool(_session_id)
    response = _forward_once(request)
    if sent_session and _last_http_status == 404 and _initialize_request:
        recovered = _forward_once(_initialize_request)
        if _is_successful_initialize_response(_initialize_request, recovered):
            return _forward_once(request)
    return response


def _stop(_signum, _frame):
    global _stopping
    _stopping = True


def main():
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    for line in sys.stdin:
        if _stopping:
            break
        if not line.strip():
            continue
        try:
            request = json.loads(line)
            if not isinstance(request, dict):
                raise ValueError("JSON-RPC message is not an object")
            responses = forward(request)
            # Notifications have no response. The endpoint may still return an
            # acknowledgement, but forwarding it is harmless only if it is JSON-RPC.
            if "id" not in request:
                continue
            for response in responses:
                sys.stdout.write(json.dumps(response, separators=(",", ":")) + "\n")
                sys.stdout.flush()
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
            _diagnostic("invalid JSON-RPC input")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
