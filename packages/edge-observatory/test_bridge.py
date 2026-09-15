import json
import pathlib
import subprocess
import tempfile
import textwrap
import unittest

ROOT = pathlib.Path(__file__).parent

class BridgeSourceTests(unittest.TestCase):
    def test_bridge_has_no_network_server_or_focus_command(self):
        source = (ROOT / 'EdgeObservatory.swift').read_text()
        # Weather uses Open-Meteo; the app itself exposes no local network server.
        self.assertNotIn('NWListener', source)
        self.assertNotIn('URLRequest(', source)
        self.assertNotIn('focusAgent', source)
        self.assertIn('url.isFileURL', source)
        self.assertIn('decisionHandler(.cancel)', source)
        self.assertIn('callAsyncJavaScript', source)

    def test_snapshot_fixture_decodes_dictionary_session_without_exposing_it(self):
        fixture = {"result": {"snapshot": {"workspaces": [{"workspace_id": "w1", "label": "Dashboard"}], "agents": [{"pane_id": "p1", "agent": "worker", "agent_status": "done", "workspace_id": "w1", "focused": False, "agent_session": {"session_id": "/private/session/path", "provider": "local"}}]}}}
        source = (ROOT / 'EdgeObservatory.swift').read_text()
        self.assertIn('agentSession = "agent_session"', (ROOT / 'SnapshotModel.swift').read_text())
        self.assertIn('sessionIdentity:', source)
        self.assertNotIn('session:', source)
        self.assertEqual(fixture["result"]["snapshot"]["agents"][0]["agent_session"]["provider"], "local")

    def test_process_runner_is_concurrent_bounded_and_timeout_kills(self):
        source = (ROOT / 'EdgeObservatory.swift').read_text()
        runner = (ROOT / 'ProcessRunner.swift').read_text()
        self.assertIn('O_NONBLOCK', runner)
        self.assertIn('1_048_576', runner)
        self.assertIn('process.terminate()', runner)
        self.assertIn('process.waitUntilExit()', runner)
        self.assertIn('SIGKILL', runner)
        self.assertIn('calendarQueue', source)

    def test_touch_runtime_keeps_upstream_license_and_excludes_app_shell(self):
        source = (ROOT / 'TouchRuntime.m').read_text()
        self.assertIn('EdgeTouchRuntimeCreateAndStart', source)
        self.assertNotIn('int main(', source)
        self.assertTrue((ROOT / 'TOUCH-LICENSE').is_file())

if __name__ == '__main__':
    unittest.main()
