# Google Drive MCP auth bridge

`google-drive-mcp-auth` adapts the Google Drive Streamable HTTP MCP endpoint to
stdio. It obtains a short-lived access token with `gcloud auth
print-access-token`, forwards the MCP session id, and forwards the negotiated
`MCP-Protocol-Version` header on requests after `initialize`.

The bridge reads a bounded response with a 30-second request timeout and parses
JSON or SSE `data:` events. It intentionally supports the endpoint behavior of
one complete SSE response per request; it is not a long-lived streaming/event
listener. A stale session is discarded when the upstream returns HTTP 404 (the
MCP invalid-session status). Recovery is attempted only when that request sent
a session id and a previously successful initialize response is cached; the
bridge then reinitializes with a fresh token and retries the failed request once.
Other HTTP errors, including HTTP 400, are returned without retrying.

The work host enables the `gcloud` Home Manager module because the bridge
requires the `gcloud` executable and the selected credential source is gcloud.
