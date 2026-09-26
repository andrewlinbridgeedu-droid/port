"""Per-player, per-battle passive-evidence gate. Integer time, no deferred awards.

The rolling window is (tick-window_ticks, tick]. Exact expiry is reusable.
A grant counts an accepted base trigger, not a relic's separately attributed bonus.
Only call with has_capacity=True when the base +1 can actually enter the ledger.
This reference is single-threaded: validation and grant must be one transaction.
"""
from __future__ import annotations
from collections import Counter, deque
from dataclasses import dataclass
from typing import Hashable

@dataclass(frozen=True)
class GateDecision:
    accepted: bool
    reason: str

class PassiveEvidenceGate:
    def __init__(self, *, window_ticks: int = 100, limit: int = 2,
                 per_enemy_ticks: int = 100) -> None:
        if any(type(x) is not int or x <= 0 for x in
               (window_ticks, limit, per_enemy_ticks)):
            raise ValueError('Gate parameters must be positive integers')
        self.window_ticks = window_ticks
        self.limit = limit
        self.per_enemy_ticks = per_enemy_ticks
        self._accepted: deque[int] = deque()
        self._next_enemy: dict[Hashable, int] = {}
        self._seen: set[Hashable] = set()
        self._last_tick = -1
        self.stats: Counter[str] = Counter()

    def attempt(self, tick: int, enemy_id: Hashable, hit_id: Hashable, *,
                eligible: bool = True, has_capacity: bool = True) -> GateDecision:
        if type(tick) is not int or tick < 0 or tick < self._last_tick:
            raise ValueError('Events require nonnegative, monotonically ordered integer ticks')
        self._last_tick = tick
        while self._accepted and self._accepted[0] <= tick-self.window_ticks:
            self._accepted.popleft()
        if hit_id in self._seen:
            reason = 'duplicate_hit'
        else:
            # Deduplicate all callbacks, including rejected ones. Never replay later.
            self._seen.add(hit_id)
            if not eligible:
                reason = 'ineligible'
            elif not has_capacity:
                reason = 'ledger_full'
            elif tick < self._next_enemy.get(enemy_id, -1):
                reason = 'per_enemy_cooldown'
            elif len(self._accepted) >= self.limit:
                reason = 'global_rolling_limit'
            else:
                reason = 'accepted'
                self._accepted.append(tick)
                self._next_enemy[enemy_id] = tick+self.per_enemy_ticks
        self.stats[reason] += 1
        return GateDecision(reason == 'accepted', reason)
