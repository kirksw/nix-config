import unittest
from server import UnreadTracker


class UnreadTests(unittest.TestCase):
    def setUp(self):
        self.tracker = UnreadTracker()

    def state(self, status, focused=False, session='a'):
        agents = [{'pane_id': 'p1', 'agent_status': status, 'focused': focused,
                   'agent_session': session}]
        self.tracker.update(agents)
        return agents[0]['unread']

    def test_initial_done_is_unread_until_opened(self):
        self.assertTrue(self.state('done'))
        self.assertFalse(self.state('done', focused=True))
        self.assertFalse(self.state('done'))

    def test_done_without_sampled_working_is_unread(self):
        self.state('idle')
        self.assertTrue(self.state('done'))

    def test_initial_idle_is_read(self):
        self.assertFalse(self.state('idle'))

    def test_completion_retained_until_focus(self):
        self.state('working')
        self.assertTrue(self.state('idle'))
        self.assertTrue(self.state('idle'))
        self.assertFalse(self.state('idle', focused=True))
        self.assertFalse(self.state('idle'))

    def test_focused_completion_is_read(self):
        self.state('working')
        self.assertFalse(self.state('done', focused=True))

    def test_blocked_is_not_complete(self):
        self.state('working')
        self.assertFalse(self.state('blocked'))

    def test_replaced_session_is_not_unread(self):
        self.state('working')
        self.assertFalse(self.state('idle', session='b'))

    def test_removed_pane_is_forgotten(self):
        self.state('working')
        self.tracker.update([])
        self.assertFalse(self.state('idle'))


if __name__ == '__main__':
    unittest.main()
