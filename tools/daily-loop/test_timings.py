"""Synthetic validator tests, not gameplay observations."""
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('timings', Path(__file__).with_name('timings.py'))
timings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(timings)

class TimingValidationTests(unittest.TestCase):
    def data(self):
        return {'schema': 1, 'activities': {name: {'samples': [
            {'date': '2026-09-29', 'build': 169, 'mode': 'human-normal-play', 'device': 'synthetic',
             'context': 'synthetic validator test', 'observer': 'synthetic', 'evidence': 'synthetic', 'seconds': n}
            for n in [90, 30, 60]]} for name in timings.ACTIVITIES}}
    def test_median_and_seconds_to_minutes(self):
        errors, result = timings.summarize(self.data())
        self.assertEqual(errors, [])
        self.assertEqual(result['story']['medianSeconds'], 60)
        self.assertEqual(result['story']['medianMinutes'], 1)
    def test_missing_samples(self):
        data = self.data(); data['activities']['story']['samples'].pop()
        self.assertTrue(timings.summarize(data)[0])
    def test_invalid_or_automatic_observations_rejected(self):
        for field, value in [('seconds', float('nan')), ('seconds', -1), ('seconds', True),
                             ('mode', 'automated'), ('build', None), ('date', 'unknown'), ('evidence', '')]:
            with self.subTest(field=field, value=value):
                data = self.data(); data['activities']['story']['samples'][0][field] = value
                self.assertTrue(timings.summarize(data)[0])
    def test_mixed_builds(self):
        data = self.data(); data['activities']['story']['samples'][0]['build'] = 168
        self.assertTrue(timings.summarize(data)[0])
    def test_missing_category(self):
        data = self.data(); del data['activities']['neighbor_find']
        self.assertTrue(timings.summarize(data)[0])

if __name__ == '__main__': unittest.main()
