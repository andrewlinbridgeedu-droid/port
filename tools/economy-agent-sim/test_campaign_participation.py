import itertools
import math
import unittest
from fractions import Fraction as F

from campaign_participation import (POLICIES, compare_scores, score_probabilities, binomial_pmf,
    threshold_deaths, compare_route_points, route_probabilities, PublicFront, Contribution,
    core_caps_from_progress)


class ParticipationTests(unittest.TestCase):
    def test_small_distributions_against_independent_binary_tapes(self):
        for na, nb, pa, pb, policy in itertools.product((2, 4), (2, 4), (F(7, 20), F(1, 2)),
                                                       (F(1, 2), F(13, 20)), POLICIES):
            exact = {k: F(0) for k in ("A_leads", "B_leads", "tied_ready", "neither_ready")}
            for tape in itertools.product((0, 1), repeat=na + nb):
                a, b = sum(tape[:na]), sum(tape[na:])
                key = compare_scores(na, nb, a, b, policy, required=2)
                exact[key] += pa**a * (1-pa)**(na-a) * pb**b * (1-pb)**(nb-b)
            model = score_probabilities(na, nb, pa, pb, policy, required=2)
            for k in exact:
                self.assertAlmostEqual(model[k], float(exact[k]), places=12)

    def test_integer_ties_symmetry_and_direction(self):
        self.assertEqual(compare_scores(100, 25, 40, 20, "sqrt_roster"), "tied_ready")
        self.assertEqual(compare_scores(100, 25, 40, 10, "win_fraction"), "tied_ready")
        for policy in POLICIES:
            x = score_probabilities(14, 6, .35, .65, policy)
            y = score_probabilities(6, 14, .65, .35, policy)
            self.assertAlmostEqual(x["A_leads"], y["B_leads"])

    def test_empty_and_subminimum_rosters_do_not_fake_progress(self):
        for policy in POLICIES:
            self.assertEqual(score_probabilities(0, 0, .5, .5, policy)["neither_ready"], 1.)
            self.assertEqual(compare_scores(3, 3, 3, 3, policy), "neither_ready")
            self.assertEqual(compare_scores(6, 0, 4, 0, policy), "A_leads")

    def test_monotonic_wins_in_fixed_roster(self):
        order = {"B_leads": 0, "neither_ready": 0, "tied_ready": 1, "A_leads": 2}
        for policy in POLICIES:
            for b in range(11):
                outcomes = [order[compare_scores(10, 10, a, b, policy)] for a in range(11)]
                self.assertEqual(outcomes, sorted(outcomes))

    def test_large_binomial_mass_and_known_mean(self):
        for n, p in itertools.product((20, 100, 400), (.175, .35, .5, .65)):
            pmf = binomial_pmf(n, p)
            self.assertAlmostEqual(math.fsum(pmf), 1, places=11)
            self.assertAlmostEqual(math.fsum(i * x for i, x in enumerate(pmf)), n*p, places=9)
        self.assertEqual(binomial_pmf(4, 0), [1., 0., 0., 0., 0.])
        self.assertEqual(binomial_pmf(4, 1), [0., 0., 0., 0., 1.])

    def test_public_fixed_threshold_is_not_a_race(self):
        d = threshold_deaths(6, 6, .5, .5)
        self.assertAlmostEqual(d["both_dead"], (22/64)**2)
        self.assertGreater(d["both_dead"], 45/1024)

    def test_invalid_input_cannot_enter_comparison(self):
        for args in [(3, 3, 4, 1, "raw_wins"), (3, 3, 1, 1, "unknown"),
                     (True, 3, 1, 1, "raw_wins")]:
            with self.assertRaises(ValueError):
                compare_scores(*args)

    def test_route_weights_do_not_replace_distinct_success_requirement(self):
        self.assertEqual(compare_route_points(10, 10, 3, 4, (2, 1)), "B_leads")
        self.assertEqual(compare_route_points(10, 10, 8, 4, (1, 2)), "tied_ready")
        self.assertEqual(compare_route_points(10, 10, 7, 4, (1, 2)), "B_leads")
        with self.assertRaises(ValueError):
            compare_route_points(10, 10, 8, 4, (1, 99))
        self.assertAlmostEqual(route_probabilities(70, 30, .5, .65)["B_leads"], .7013813863877)

    def test_new_participant_never_decreases_existing_points(self):
        s = PublicFront.start({"a": "A", "beginner": "A", "b": "B"})
        s = s.settle(Contribution("one", "a", "hard", True))
        self.assertEqual(s.totals()["A"]["points"], 2)
        failed = s.settle(Contribution("two", "beginner", "ordinary", False))
        won = s.settle(Contribution("two", "beginner", "ordinary", True))
        self.assertEqual(failed.totals()["A"]["points"], 2)
        self.assertEqual(won.totals()["A"]["points"], 3)

    def test_public_receipts_are_idempotent_and_defeat_consumes_attempt(self):
        s = PublicFront.start({"a": "A", "b": "B"})
        result = Contribution("one", "a", "hard", False)
        s = s.settle(result)
        self.assertEqual(s.settle(result), s)
        for r in [Contribution("one", "a", "hard", True),
                  Contribution("two", "a", "ordinary", True),
                  Contribution("two", "missing", "ordinary", True)]:
            with self.assertRaises(ValueError):
                s.settle(r)
        self.assertEqual(s.totals()["A"], {"wins": 0, "points": 0, "attempts": 1})

    def test_closed_front_rejects_new_results_but_preserves_replay(self):
        s = PublicFront.start({"a": "A", "b": "B"})
        r = Contribution("one", "a", "hard", True)
        s = s.settle(r).close()
        self.assertEqual(s.settle(r), s)
        with self.assertRaises(ValueError):
            s.settle(Contribution("two", "b", "hard", True))
        self.assertEqual(s.totals()["B"]["points"], 0)

    def test_public_lead_changes_opportunity_but_cannot_kill_or_fabricate_candidates(self):
        self.assertEqual(core_caps_from_progress((7,7),(7,14)),(4,6))
        self.assertEqual(core_caps_from_progress((7,7),(7,7)),(5,5))
        self.assertEqual(core_caps_from_progress((4,6),(8,6)),(4,4))
        self.assertEqual(core_caps_from_progress((3,6),(6,6)),(0,6))
        self.assertEqual(core_caps_from_progress((7,7),(14,7),(False,True)),(0,6))
        self.assertEqual(core_caps_from_progress((7,7),(14,7),(False,False)),(0,0))
        s=PublicFront.start({f'{side}{n}':side for side in ('A','B') for n in range(6)})
        with self.assertRaises(ValueError):
            s.core_opportunity_caps()
        for side in ('A','B'):
            for n in range(6):
                s=s.settle(Contribution(f'{side}{n}',f'{side}{n}',
                                       'hard' if side=='B' else 'ordinary',True))
        self.assertEqual(s.close().core_opportunity_caps(),(4,6))


if __name__ == "__main__":
    unittest.main()
