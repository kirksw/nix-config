import unittest
from unittest.mock import patch, Mock
import subprocess
import supervisor


class SupervisorTests(unittest.TestCase):
    def test_exact_monitor_match(self):
        for output, expected in [('1 | ROG PG279QM\n', False),
                                 ('1 | XENEON EDGE\n', True),
                                 ('1 | XENEON EDGE fake\n', False)]:
            with patch.object(supervisor, 'command', return_value=output):
                self.assertEqual(supervisor.edge_connected(), expected)

    def test_query_failure_is_not_disconnect(self):
        with patch.object(supervisor, 'command', side_effect=subprocess.TimeoutExpired('aerospace', 8)):
            with self.assertRaises(subprocess.TimeoutExpired):
                supervisor.edge_connected()

    def test_stop_only_owned_process(self):
        process = Mock()
        process.poll.return_value = None
        supervisor.stop(process)
        process.terminate.assert_called_once()
        process.wait.assert_called_once_with(timeout=8)

    def test_stop_escalates_after_timeout(self):
        process = Mock()
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired('helper', 8), None]
        supervisor.stop(process)
        process.kill.assert_called_once()
