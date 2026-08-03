import io
import importlib.util
import json
import pathlib
import unittest
import urllib.error
from unittest import mock


MODULE = pathlib.Path(__file__).with_name("google-drive-mcp-auth.py")
spec = importlib.util.spec_from_file_location("google_drive_mcp_auth", MODULE)
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class Response:
    def __init__(self, body, content_type="application/json", session=None):
        self.headers = {"content-type": content_type}
        if session:
            self.headers["mcp-session-id"] = session
        self.body = body.encode()
        self._stream = io.BytesIO(self.body)

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self, _limit=-1):
        return self.body if _limit < 0 else self.body[:_limit]

    def readline(self):
        return self._stream.readline()


class BridgeTests(unittest.TestCase):
    def setUp(self):
        bridge._session_id = None
        bridge._protocol_version = None
        bridge._initialize_request = None
        bridge._last_http_status = None

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_json_and_session_forwarding(self, urlopen, _token):
        urlopen.side_effect = [
            Response('{"jsonrpc":"2.0","id":1,"result":{}}', session="session-1"),
            Response('{"jsonrpc":"2.0","id":2,"result":{}}'),
        ]
        self.assertEqual(bridge.forward({"jsonrpc": "2.0", "id": 1}), [{"jsonrpc": "2.0", "id": 1, "result": {}}])
        bridge.forward({"jsonrpc": "2.0", "id": 2})
        first = urlopen.call_args_list[0].args[0]
        second = urlopen.call_args_list[1].args[0]
        self.assertEqual(first.get_header("Authorization"), "Bearer secret-token")
        self.assertIsNone(first.get_header("Mcp-session-id"))
        self.assertEqual(second.get_header("Mcp-session-id"), "session-1")
        self.assertEqual(json.loads(second.data), {"jsonrpc": "2.0", "id": 2})

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_protocol_version_forwarded_after_initialize(self, urlopen, _token):
        urlopen.side_effect = [
            Response('{"jsonrpc":"2.0","id":1,"result":{}}', session="session-1"),
            Response('{"jsonrpc":"2.0","id":2,"result":{}}'),
        ]
        bridge.forward(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": "2025-06-18"},
            }
        )
        bridge.forward({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        initialize_request = urlopen.call_args_list[0].args[0]
        followup_request = urlopen.call_args_list[1].args[0]
        self.assertIsNone(initialize_request.get_header("Mcp-protocol-version"))
        self.assertEqual(followup_request.get_header("Mcp-protocol-version"), "2025-06-18")
        self.assertEqual(followup_request.get_header("Mcp-session-id"), "session-1")

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_initialize_clears_cached_session_before_sending(self, urlopen, _token):
        bridge._session_id = "stale-session"
        urlopen.side_effect = [
            Response('{"jsonrpc":"2.0","id":1,"result":{}}', session="new-session"),
            Response('{"jsonrpc":"2.0","id":2,"result":{}}'),
        ]
        bridge.forward(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": "2025-06-18"},
            }
        )
        bridge.forward({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        initialize_request = urlopen.call_args_list[0].args[0]
        followup_request = urlopen.call_args_list[1].args[0]
        self.assertIsNone(initialize_request.get_header("Mcp-session-id"))
        self.assertEqual(followup_request.get_header("Mcp-session-id"), "new-session")

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_invalid_session_clears_cached_session(self, urlopen, _token):
        bridge._session_id = "stale-session"
        error = urllib.error.HTTPError(bridge.ENDPOINT, 404, "invalid session", {}, None)
        urlopen.side_effect = [error, Response('{"jsonrpc":"2.0","id":2,"result":{}}')]
        bridge.forward({"jsonrpc": "2.0", "id": 1, "method": "tools/list"})
        bridge.forward({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        self.assertEqual(urlopen.call_args_list[0].args[0].get_header("Mcp-session-id"), "stale-session")
        self.assertIsNone(urlopen.call_args_list[1].args[0].get_header("Mcp-session-id"))

    @mock.patch.object(bridge, "_token", side_effect=["old-token", "fresh-token", "fresh-token", "fresh-token"])
    @mock.patch.object(bridge, "_open")
    def test_invalid_session_reinitializes_and_retries_once(self, urlopen, _token):
        bridge._session_id = "stale-session"
        initialize = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {"protocolVersion": "2025-06-18"},
        }
        error = urllib.error.HTTPError(bridge.ENDPOINT, 404, "invalid session", {}, None)
        urlopen.side_effect = [
            Response('{"jsonrpc":"2.0","id":1,"result":{}}', session="new-session"),
            error,
            Response('{"jsonrpc":"2.0","id":1,"result":{}}', session="recovered-session"),
            Response('{"jsonrpc":"2.0","id":2,"result":{}}'),
        ]
        bridge.forward(initialize)
        response = bridge.forward({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        self.assertEqual(response[0]["id"], 2)
        self.assertEqual(urlopen.call_count, 4)
        recovered_initialize = urlopen.call_args_list[2].args[0]
        retry = urlopen.call_args_list[3].args[0]
        self.assertEqual(json.loads(recovered_initialize.data), initialize)
        self.assertIsNone(recovered_initialize.get_header("Mcp-session-id"))
        self.assertEqual(recovered_initialize.get_header("Authorization"), "Bearer fresh-token")
        self.assertEqual(retry.get_header("Mcp-session-id"), "recovered-session")
        self.assertEqual(retry.get_header("Authorization"), "Bearer fresh-token")
        self.assertEqual(_token.call_count, 4)

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_non_session_400_is_not_retried(self, urlopen, _token):
        initialize = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {"protocolVersion": "2025-06-18"},
        }
        urlopen.side_effect = [
            Response('{"jsonrpc":"2.0","id":1,"result":{}}', session="session-1"),
            urllib.error.HTTPError(bridge.ENDPOINT, 400, "bad request", {}, None),
        ]
        bridge.forward(initialize)
        response = bridge.forward({"jsonrpc": "2.0", "id": 2, "method": "tools/call"})
        self.assertEqual(response[0]["error"]["message"], "Google Drive MCP returned HTTP 400")
        self.assertEqual(urlopen.call_count, 2)

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_error_status_with_valid_body_is_forwarded(self, urlopen, _token):
        # The preview endpoint can return a complete JSON-RPC response with an
        # HTTP error status (observed: HTTP 403 carrying a tools/list result).
        body = b'{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
        error = urllib.error.HTTPError(
            bridge.ENDPOINT, 403, "forbidden", {"content-type": "application/json"}, io.BytesIO(body)
        )
        urlopen.side_effect = error
        response = bridge.forward({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        self.assertEqual(response, [{"jsonrpc": "2.0", "id": 2, "result": {"tools": []}}])

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_error_status_with_invalid_body_still_fails(self, urlopen, _token):
        error = urllib.error.HTTPError(
            bridge.ENDPOINT, 403, "forbidden", {"content-type": "application/json"}, io.BytesIO(b"not json")
        )
        urlopen.side_effect = error
        response = bridge.forward({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        self.assertEqual(response[0]["error"]["message"], "Google Drive MCP returned HTTP 403")

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_failed_initialize_is_not_used_for_recovery(self, urlopen, _token):
        initialize = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {"protocolVersion": "2025-06-18"},
        }
        urlopen.side_effect = [
            urllib.error.HTTPError(bridge.ENDPOINT, 500, "failed initialize", {}, None),
            Response('{"jsonrpc":"2.0","id":2,"result":{}}'),
        ]
        bridge.forward(initialize)
        bridge.forward({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        self.assertEqual(urlopen.call_count, 2)
        self.assertIsNone(urlopen.call_args_list[1].args[0].get_header("Mcp-session-id"))

    def test_redirect_handler_does_not_follow_cross_origin_redirect(self):
        handler = bridge._NoRedirectHandler()
        request = bridge.urllib.request.Request(bridge.ENDPOINT, headers={"Authorization": "Bearer secret"})
        self.assertIsNone(handler.redirect_request(request, mock.Mock(), 302, "Found", {}, "https://evil.example"))

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_malformed_upstream_response_returns_internal_error(self, urlopen, _token):
        urlopen.return_value = Response("not json")
        response = bridge.forward({"jsonrpc": "2.0", "id": 4, "method": "tools/list"})
        self.assertEqual(response[0]["error"]["code"], -32603)
        self.assertEqual(response[0]["id"], 4)
        self.assertIn("invalid response", response[0]["error"]["message"])

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_oversized_upstream_response_returns_internal_error(self, urlopen, _token):
        urlopen.return_value = Response("x" * (bridge.MAX_RESPONSE_BYTES + 1))
        response = bridge.forward({"jsonrpc": "2.0", "id": 5, "method": "tools/list"})
        self.assertEqual(response[0]["error"]["code"], -32603)
        self.assertEqual(response[0]["id"], 5)
        self.assertIn("invalid response", response[0]["error"]["message"])

    @mock.patch.object(bridge, "_token", return_value="secret-token")
    @mock.patch.object(bridge, "_open")
    def test_sse_data_events(self, urlopen, _token):
        urlopen.return_value = Response(
            "event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{}}\n\n"
            "data: [DONE]\n\n",
            "text/event-stream",
        )
        self.assertEqual(bridge.forward({"jsonrpc": "2.0", "id": 3})[0]["id"], 3)


if __name__ == "__main__":
    unittest.main()
