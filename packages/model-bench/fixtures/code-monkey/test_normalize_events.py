import unittest
from solution import normalize_events


class NormalizeEventsTest(unittest.TestCase):
    def test_dedupes_and_sorts_valid_events(self):
        events = [
            {"id": "b", "timestamp": 30, "amount": "12.50", "currency": "dkk"},
            {"id": "a", "timestamp": 10, "amount": 7, "currency": "EUR"},
            {"id": "b", "timestamp": 20, "amount": 99, "currency": "DKK"},
        ]
        self.assertEqual(
            normalize_events(events),
            [
                {"id": "a", "timestamp": 10, "amount": 7.0, "currency": "EUR"},
                {"id": "b", "timestamp": 30, "amount": 12.5, "currency": "DKK"},
            ],
        )

    def test_skips_invalid_records_without_mutating_input(self):
        events = [
            {"id": "ok", "timestamp": 1, "amount": 1, "currency": "usd"},
            {"id": "missing-amount", "timestamp": 2, "currency": "USD"},
            {"id": "bad-amount", "timestamp": 3, "amount": "nope", "currency": "USD"},
            {"id": "bad-timestamp", "timestamp": "later", "amount": 4, "currency": "USD"},
            {"id": "bad-currency", "timestamp": 5, "amount": 4, "currency": "US"},
        ]
        original = [dict(item) for item in events]
        self.assertEqual(normalize_events(events), [{"id": "ok", "timestamp": 1, "amount": 1.0, "currency": "USD"}])
        self.assertEqual(events, original)

    def test_empty_input(self):
        self.assertEqual(normalize_events([]), [])


if __name__ == "__main__":
    unittest.main()
