"""Pure in-memory rules used by tests; NOT an authoritative game/save service.
Calls assume the combat result was validated by an external engine.
No cryptography, persistent transactions, network concurrency, or Unity integration.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from copy import deepcopy
from typing import Any

@dataclass
class State:
    completed_quests: set[str] = field(default_factory=set)
    highest: dict[str,int] = field(default_factory=lambda:dict(L=0,M=0,A=0))
    first_clears: set[str] = field(default_factory=set)
    wallet: dict[str,int] = field(default_factory=lambda:dict(xp=0,crowns=0,essence=0))
    research: dict[str,int] = field(default_factory=lambda:dict(L=0,M=0,A=0))
    receipts: dict[str,dict[str,Any]] = field(default_factory=dict)
    calibration_paid: list[dict[str,int]] = field(default_factory=list)
    active_battle: bool = False
    xp_overflow: int = 0
    cosmetics: set[str] = field(default_factory=set)


def apply_design_clear(state: State, floor: dict, battle_id: str, result: str,
                       rules_version: str='fixture_rules') -> tuple[State,dict]:
    """Model first-clear accounting after a hypothetical externally verified result.
    Does not check release_enabled because these are offline, draft-only fixtures.
    The real client must reject unreleased/unverified battle configurations.
    """
    if not battle_id or result not in {'win','loss','abort'}:
        raise ValueError('invalid result identity')
    church=floor['church']; number=floor['number']; floor_id=floor['id']
    payload={'floor_id':floor_id,'result':result,'rules_version':rules_version}
    old=state.receipts.get(battle_id)
    if old:
        if old['payload'] != payload:
            raise ValueError('conflicting reuse of battle_id')
        return deepcopy(state),dict(old,credited_now=False)
    if floor['story_gate'] not in state.completed_quests:
        raise ValueError('story not yet unlocked')
    if number>state.highest[church]+1:
        raise ValueError('cannot skip an uncleared predecessor')
    if number<=state.highest[church] and floor_id not in state.first_clears:
        raise ValueError('inconsistent progress; requires reconciliation')
    new=deepcopy(state)
    reward=dict(xp=0,crowns=0,essence=0,research=0)
    credited=result=='win' and floor_id not in state.first_clears
    if credited:
        reward={k:floor['first_clear_reward'][k] for k in reward}
        applied_xp=min(reward['xp'],max(0,2340-new.wallet['xp']))
        new.wallet['xp']+=applied_xp
        new.xp_overflow+=reward['xp']-applied_xp
        for key in ('crowns','essence'):
            new.wallet[key]+=reward[key]
        cosmetic=floor['first_clear_reward'].get('cosmetic')
        if cosmetic:
            new.cosmetics.add(cosmetic)
        new.research[church]+=reward['research']
        new.first_clears.add(floor_id)
        new.highest[church]=number
    receipt={'payload':payload,'reward':reward,'credited_now':credited}
    new.receipts[battle_id]=receipt
    return new,deepcopy(receipt)


def set_calibration(state: State, target_rank: int, config: dict) -> State:
    """Pure transition. Refunds the recorded costs, not a newly hotfixed price table."""
    if type(target_rank) is not int or not 0<=target_rank<=5:
        raise ValueError('rank must be an integer from 0 to 5')
    if state.active_battle:
        raise ValueError('cannot change a battle snapshot')
    if 'Q08' not in state.completed_quests:
        raise ValueError('calibration requires Q08')
    if state.wallet['xp'] < 2340:
        raise ValueError('calibration requires earned level 10')
    new=deepcopy(state)
    current=len(new.calibration_paid)
    if target_rank>current:
        costs=config['rank_costs'][current:target_rank]
        needed={k:sum(c[k] for c in costs) for k in ('crowns','essence')}
        if any(new.wallet[k]<needed[k] for k in needed):
            raise ValueError('insufficient resources; no partial purchase')
        for k in needed:
            new.wallet[k]-=needed[k]
        new.calibration_paid.extend({k:c[k] for k in ('crowns','essence')} for c in costs)
    else:
        for cost in new.calibration_paid[target_rank:]:
            for k in ('crowns','essence'):
                new.wallet[k]+=cost[k]
        del new.calibration_paid[target_rank:]
    return new


def project_s9(level: int, calibration_rank: int) -> dict[str,int]:
    if type(level) is not int or not 1<=level<=10:
        raise ValueError('invalid earned sequence9 level')
    if type(calibration_rank) is not int or not 0<=calibration_rank<=5:
        raise ValueError('invalid earned calibration rank')
    hp=1800+600*(level-1)//9
    attack=80+20*(level-1)//9
    return {'hp':hp+48*calibration_rank,'attack':attack+2*calibration_rank}
