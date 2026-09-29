import unittest
from campaign_core_race import Result, start_race, settle_wave, exact_probabilities


def roster(n=6):
    return {f"{s}{i}": s for s in "AB" for i in range(1, n + 1)}


def win_wave(state, n):
    return settle_wave(state, n, (Result("A", f"A{n}", "success"), Result("B", f"B{n}", "success")))


class CoreRaceTests(unittest.TestCase):
    def test_four_distinct_simultaneous_wins_draw_and_stop(self):
        s = start_race("event", (6, 6), roster())
        for n in range(1, 4):
            s = win_wave(s, n)
            self.assertIsNone(s.outcome)
            self.assertEqual(s.dead_npcs, ())
        s = win_wave(s, 4)
        self.assertEqual(s.outcome, "both")
        self.assertEqual(s.dead_npcs, ("A", "B"))
        self.assertEqual(len(s.used_accounts), 8)
        self.assertEqual(s, win_wave(s, 4))
        with self.assertRaises(ValueError):
            win_wave(s, 5)

    def test_late_results_cannot_rewrite_winner(self):
        s = start_race("event", (6, 6), roster())
        for n in range(1, 5):
            s = settle_wave(s, n, (Result("A", f"A{n}", "success"), Result("B", f"B{n}", "defeat")))
        self.assertEqual(s.outcome, "A")
        self.assertEqual(s.dead_npcs, ("B",))
        with self.assertRaises(ValueError):
            win_wave(s, 4)
        self.assertEqual(s.breaches, (4, 0))

    def test_failed_attempt_cannot_reenter_or_switch_faction(self):
        s = start_race("event", (5, 5), roster())
        s = settle_wave(s, 1, (Result("A", "A1", "defeat"), Result("B", "B1", "timeout")))
        for bad in [Result("A", "A1", "success"), Result("A", "B2", "success")]:
            with self.assertRaises(ValueError):
                settle_wave(s, 2, (bad, Result("B", "B2", "success")))
        self.assertEqual(s.breaches, (0, 0))
        self.assertEqual(s.wave, 2)

    def test_incomplete_or_duplicate_wave_is_rejected_atomically(self):
        s = start_race("event", (6, 6), roster())
        for results in [(Result("A", "A1", "success"),),
                        (Result("A", "A1", "success"), Result("A", "A2", "success")),
                        (Result("A", "A1", "success"), Result("B", "missing", "success"))]:
            with self.assertRaises(ValueError):
                settle_wave(s, 1, results)
        self.assertEqual(s.used_accounts, ())
        with self.assertRaises(ValueError):
            win_wave(s, 2)

    def test_unfilled_slots_exhaust_caps_without_fake_players(self):
        s = start_race("event", (4, 4), {})
        for n in range(1, 5):
            s = settle_wave(s, n, (Result("A", None, "unfilled"), Result("B", None, "unfilled")))
        self.assertEqual(s.outcome, "neither")
        self.assertEqual(s.used_accounts, ())
        self.assertEqual(s.breaches, (0, 0))

    def test_asymmetric_cap_allows_later_wave_for_remaining_faction(self):
        s = start_race("event", (6, 4), roster())
        for n in range(1, 5):
            s = settle_wave(s, n, (Result("A", f"A{n}", "success" if n > 2 else "defeat"),
                                   Result("B", f"B{n}", "defeat")))
        s = settle_wave(s, 5, (Result("A", "A5", "success"),))
        s = settle_wave(s, 6, (Result("A", "A6", "success"),))
        self.assertEqual(s.outcome, "A")
        self.assertEqual(s.breaches, (4, 0))

    def test_no_world_effect_before_fourth_success(self):
        s = start_race("event", (6, 6), roster())
        for n in range(1, 7):
            s = settle_wave(s, n, (Result("A", f"A{n}", "success" if n <= 3 else "defeat"),
                                   Result("B", f"B{n}", "defeat")))
        self.assertEqual(s.outcome, "neither")
        self.assertEqual(s.dead_npcs, ())

    def test_probabilities_have_absorbing_outcomes_and_side_symmetry(self):
        from fractions import Fraction as F
        a = exact_probabilities((6, 6), F(1, 2), F(1, 2))
        self.assertEqual(a, {"A": F(269, 1024), "B": F(269, 1024),
                            "both": F(45, 1024), "neither": F(441, 1024)})
        x = exact_probabilities((6, 4), F(7, 20), F(13, 20))
        y = exact_probabilities((4, 6), F(13, 20), F(7, 20))
        self.assertEqual(x["A"], y["B"])
        self.assertEqual(x["both"], y["both"])
        self.assertEqual(exact_probabilities((6, 6), 1, 1)["both"], 1)
        self.assertEqual(exact_probabilities((6, 6), 0, 0)["neither"], 1)

    def test_invalid_caps_and_closed_empty_race(self):
        for caps in [(7, 6), (-1, 6), (True, 6)]:
            with self.assertRaises(ValueError):
                start_race("event", caps, {})
        self.assertEqual(start_race("event", (0, 0), {}).outcome, "neither")


if __name__ == "__main__":
    unittest.main()
