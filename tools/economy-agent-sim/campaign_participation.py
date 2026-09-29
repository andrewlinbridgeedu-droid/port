"""Offline comparison of broad-participation scoring, not NPC death rules.

One verified result per registered account is an upstream assumption. The frozen
roster denominator includes absences. These functions neither issue tickets nor
consume real items, and a score lead never issues an NPC death receipt.
"""
from __future__ import annotations

from dataclasses import dataclass, replace
import math


POLICIES = ("raw_wins", "sqrt_roster", "win_fraction")


def compare_scores(n_a, n_b, wins_a, wins_b, policy, required=4):
    if policy not in POLICIES:
        raise ValueError("unknown policy")
    if any(type(x) is not int for x in (n_a, n_b, wins_a, wins_b, required)):
        raise ValueError("counts must be integers")
    if min(n_a, n_b, wins_a, wins_b) < 0 or wins_a > n_a or wins_b > n_b or required < 1:
        raise ValueError("invalid counts")
    a_ready, b_ready = wins_a >= required, wins_b >= required
    if not a_ready and not b_ready:
        return "neither_ready"
    if not a_ready:
        return "B_leads"
    if not b_ready:
        return "A_leads"
    # All comparisons use exact integer cross-products; no floating tie epsilon.
    if policy == "raw_wins":
        left, right = wins_a, wins_b
    elif policy == "sqrt_roster":
        left, right = wins_a * wins_a * n_b, wins_b * wins_b * n_a
    else:
        left, right = wins_a * n_b, wins_b * n_a
    return "A_leads" if left > right else "B_leads" if right > left else "tied_ready"


def binomial_pmf(n, p):
    p = float(p)
    if type(n) is not int or n < 0 or not 0 <= p <= 1:
        raise ValueError("invalid binomial inputs")
    if p == 0:
        return [1.] + [0.] * n
    if p == 1:
        return [0.] * n + [1.]
    # Here n <= 400 and .175 <= p <= .65; no tail underflow in this study.
    values = [(1 - p) ** n]
    for k in range(n):
        values.append(values[-1] * (n - k) / (k + 1) * p / (1 - p))
    if not math.isclose(math.fsum(values), 1, abs_tol=1e-11):
        raise ArithmeticError("probability mass lost")
    return values


def score_probabilities(n_a, n_b, p_a, p_b, policy, required=4):
    # Exercise validation even for degenerate distributions.
    compare_scores(n_a, n_b, 0, 0, policy, required)
    a, b = binomial_pmf(n_a, p_a), binomial_pmf(n_b, p_b)
    out = {k: 0. for k in ("A_leads", "B_leads", "tied_ready", "neither_ready")}
    for wa, pa in enumerate(a):
        for wb, pb in enumerate(b):
            out[compare_scores(n_a, n_b, wa, wb, policy, required)] += pa * pb
    assert math.isclose(sum(out.values()), 1, abs_tol=1e-10)
    return out


def threshold_deaths(n_a, n_b, p_a, p_b, required=4):
    # Deliberately unsafe control: everyone can attempt once, fixed four wins
    # per side, all results settle at the common deadline, no race truncation.
    a, b = binomial_pmf(n_a, p_a), binomial_pmf(n_b, p_b)
    qa, qb = (min(1., max(0., sum(x[required:]))) for x in (a, b))
    return {"A_exclusive": qa * (1 - qb), "B_exclusive": qb * (1 - qa),
            "both_dead": qa * qb, "none_dead": (1 - qa) * (1 - qb)}


ROUTE_POINTS = {"ordinary": 1, "hard": 2}  # Candidate, not production rewards.


def compare_route_points(n_a, n_b, wins_a, wins_b, weights=(1, 2), required=4):
    if len(weights) != 2 or any(type(w) is not int or w not in (1, 2) for w in weights):
        raise ValueError("candidate route weights are 1 or 2")
    readiness = compare_scores(n_a, n_b, wins_a, wins_b, "raw_wins", required)
    if wins_a < required or wins_b < required:
        return readiness
    a, b = wins_a * weights[0], wins_b * weights[1]
    return "A_leads" if a > b else "B_leads" if b > a else "tied_ready"


def route_probabilities(n_a, n_b, p_a, p_b, weights=(1, 2)):
    compare_route_points(n_a, n_b, 0, 0, weights)
    a, b = binomial_pmf(n_a, p_a), binomial_pmf(n_b, p_b)
    out = {k: 0. for k in ("A_leads", "B_leads", "tied_ready", "neither_ready")}
    for wa, pa in enumerate(a):
        for wb, pb in enumerate(b):
            out[compare_route_points(n_a, n_b, wa, wb, weights)] += pa * pb
    assert math.isclose(sum(out.values()), 1, abs_tol=1e-10)
    return out


def core_caps_from_progress(wins, points, supplied=(True, True)):
    """Candidate bridge: public lead earns 6 vs 4 opportunities, tie 5 vs 5.

At least four distinct public winners and separately verified project supplies
are required. No extra slot exists without an eligible account to fill it.
This maps progress to opportunities, not to an NPC kill or property transfer.
    """
    if len(wins) != 2 or len(points) != 2 or len(supplied) != 2:
        raise ValueError("two factions required")
    if any(type(x) is not int or x < 0 for x in wins + points):
        raise ValueError("invalid progress counts")
    if any(type(x) is not bool for x in supplied):
        raise ValueError("supply gates must be independently verified booleans")
    if any(not w <= p <= 2*w for w,p in zip(wins,points)):
        raise ValueError("points do not match 1/2-point successful accounts")
    ready = tuple(s and w >= 4 for s,w in zip(supplied,wins))
    if ready == (False,False):
        return (0,0)
    if ready == (True,False):
        caps = (6,0)
    elif ready == (False,True):
        caps = (0,6)
    else:
        caps = (6,4) if points[0]>points[1] else (4,6) if points[1]>points[0] else (5,5)
    return tuple(min(c,w) for c,w in zip(caps,wins))


@dataclass(frozen=True)
class Contribution:
    attempt_id: str
    account: str
    route: str
    won: bool


@dataclass(frozen=True)
class PublicFront:
    """Trusted-host offline receipt aggregation, not a client upload API.

The caller must validate encounter/version, timing and outcome. This class does
not verify combat. No cash or items are consumed and no NPC is killed here.
    """
    roster: tuple[tuple[str, str], ...]
    receipts: tuple[Contribution, ...] = ()
    closed: bool = False

    @classmethod
    def start(cls, roster):
        if any(not isinstance(a, str) or not a or s not in ("A", "B") for a, s in roster.items()):
            raise ValueError("invalid roster")
        return cls(tuple(sorted(roster.items())))

    def settle(self, result):
        if (not isinstance(result, Contribution) or not isinstance(result.attempt_id, str)
                or not result.attempt_id or result.route not in ROUTE_POINTS or type(result.won) is not bool):
            raise ValueError("invalid contribution")
        old = next((r for r in self.receipts if r.attempt_id == result.attempt_id), None)
        if old:
            if old != result:
                raise ValueError("conflicting receipt replay")
            return self
        if self.closed or result.account not in dict(self.roster):
            raise ValueError("closed or unqualified")
        if any(r.account == result.account for r in self.receipts):
            raise ValueError("one world attempt per account, defeat also consumes it")
        return replace(self, receipts=self.receipts + (result,))

    def totals(self):
        roster = dict(self.roster)
        out = {s: {"wins": 0, "points": 0, "attempts": 0} for s in ("A", "B")}
        for r in self.receipts:
            side = out[roster[r.account]]
            side["attempts"] += 1
            if r.won:
                side["wins"] += 1
                side["points"] += ROUTE_POINTS[r.route]
        return out

    def close(self):
        return replace(self, closed=True)

    def core_opportunity_caps(self, supplied=(True,True)):
        if not self.closed:
            raise ValueError("public front must close before final opportunity assignment")
        totals=self.totals()
        return core_caps_from_progress(tuple(totals[s]["wins"] for s in ("A","B")),
                                       tuple(totals[s]["points"] for s in ("A","B")), supplied)


def frozen_roster_policy_note():
    return "Register before attempts; neither late wins nor absent accounts change denominators."
