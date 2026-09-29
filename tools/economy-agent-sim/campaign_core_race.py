"""Offline core-wave policy prototype. No combat verification, network or saves.

An authoritative caller must close a wave and verify its battle receipts before
calling settle_wave. Immutable state makes rejection atomic. The state is not a
replacement for server authentication, durable transactions or permanent NPC IDs.
"""
from __future__ import annotations

from dataclasses import dataclass, replace
from fractions import Fraction


SIDES = ("A", "B")
VERDICTS = ("success", "defeat", "timeout", "unfilled")


@dataclass(frozen=True)
class Result:
    faction: str
    account: str | None
    verdict: str


@dataclass(frozen=True)
class WaveReceipt:
    wave: int
    results: tuple[Result, ...]


@dataclass(frozen=True)
class Race:
    campaign_id: str
    required: int
    caps: tuple[int, int]
    affiliations: tuple[tuple[str, str], ...]
    wave: int = 1
    breaches: tuple[int, int] = (0, 0)
    used_accounts: tuple[str, ...] = ()
    receipts: tuple[WaveReceipt, ...] = ()
    outcome: str | None = None  # A, B, both, neither

    @property
    def dead_npcs(self):
        return ("A", "B") if self.outcome == "both" else (
            ("B",) if self.outcome == "A" else ("A",) if self.outcome == "B" else ()
        )


def start_race(campaign_id, caps, affiliations, required=4):
    if not isinstance(campaign_id, str) or not campaign_id:
        raise ValueError("campaign ID required")
    if len(caps) != 2 or any(type(c) is not int or not 0 <= c <= 6 for c in caps):
        raise ValueError("two integer caps, each 0...6")
    if type(required) is not int or not 1 <= required <= 6:
        raise ValueError("invalid breach requirement")
    if any(not isinstance(a, str) or not a or f not in SIDES for a, f in affiliations.items()):
        raise ValueError("invalid fixed qualification/affiliation roster")
    return Race(campaign_id, required, tuple(caps), tuple(sorted(affiliations.items())),
                outcome="neither" if max(caps) == 0 else None)


def settle_wave(state, wave, results):
    """Settle both factions together, once. No per-faction early winner.

No-start replacement happens before this boundary. Once a wave deadline passes,
unfilled uses the faction's slot and creates no breach. Every *started* attempt,
including defeat/timeout, uses that account's only world-effect attempt.
    """
    if type(wave) is not int:
        raise ValueError("invalid wave")
    results = tuple(results)
    if any(not isinstance(r, Result) or r.faction not in SIDES or r.verdict not in VERDICTS
           for r in results):
        raise ValueError("invalid result")
    results = tuple(sorted(results, key=lambda r: r.faction))
    old = next((r for r in state.receipts if r.wave == wave), None)
    if old:
        if old.results != results:
            raise ValueError("conflicting replay")
        return state
    if state.outcome is not None or wave != state.wave:
        raise ValueError("closed or out-of-order wave")
    expected = tuple(f for i, f in enumerate(SIDES) if wave <= state.caps[i])
    if tuple(r.faction for r in results) != expected:
        raise ValueError("exactly one result for every faction with a slot")
    roster = dict(state.affiliations)
    used = set(state.used_accounts)
    breaches = list(state.breaches)
    for r in results:
        if r.verdict == "unfilled":
            if r.account is not None:
                raise ValueError("unfilled has no started account")
            continue
        if not isinstance(r.account, str) or roster.get(r.account) != r.faction or r.account in used:
            raise ValueError("unqualified, wrong faction, or repeat account")
        used.add(r.account)
        if r.verdict == "success":
            breaches[SIDES.index(r.faction)] += 1
    a, b = (n >= state.required for n in breaches)
    outcome = "both" if a and b else "A" if a else "B" if b else (
        "neither" if wave >= max(state.caps) else None
    )
    return replace(state, wave=wave + 1, breaches=tuple(breaches),
                   used_accounts=tuple(sorted(used)), outcome=outcome,
                   receipts=state.receipts + (WaveReceipt(wave, results),))


def exact_probabilities(caps, p_a, p_b, required=4):
    """Independent challenge Bernoulli assumptions; exact rational arithmetic.

Absorbing DP: cease both factions' future waves on first threshold crossing.
Individual successes are not independent after conditioning on the race ending.
    """
    ps = tuple(Fraction(p) for p in (p_a, p_b))
    if any(not 0 <= p <= 1 for p in ps):
        raise ValueError("invalid probability")
    # Validate structural fields using the same public config limits.
    start_race("probability-only", caps, {}, required)
    out = {k: Fraction(0) for k in ("A", "B", "both", "neither")}
    states = {(0, 0): Fraction(1)}
    for wave in range(1, max(caps) + 1):
        following = {}
        for (a, b), weight in states.items():
            options = [[(0, 1 - p), (1, p)] if wave <= cap else [(0, Fraction(1))]
                       for p, cap in zip(ps, caps)]
            for da, pa in options[0]:
                for db, pb in options[1]:
                    na, nb = a + da, b + db
                    mass = weight * pa * pb
                    if na >= required and nb >= required:
                        out["both"] += mass
                    elif na >= required:
                        out["A"] += mass
                    elif nb >= required:
                        out["B"] += mass
                    else:
                        following[na, nb] = following.get((na, nb), Fraction(0)) + mass
        states = following
    out["neither"] = sum(states.values(), Fraction(0))
    assert sum(out.values()) == 1
    return out
