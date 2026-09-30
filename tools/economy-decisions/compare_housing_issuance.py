"""Compares issuance with and without housing tiers in the shared model (launch_base, 5 seeds).

    python3 tools/economy-decisions/compare_housing_issuance.py 0|1
"""
import sys, statistics
from pathlib import Path
from dataclasses import replace
sys.path.insert(0, str(Path("tools/economy-decisions").resolve()))
import shared_decisions as sd
housing = sys.argv[1] == "1"
_configs = sd.v3.scenario_configs
v3 = sd.v3
rewards = list(v3.MAINLINE_REWARDS); rewards[2] += 100; rewards[4] += 100
for i in range(25, 30): rewards[i] -= 40
v3.MAINLINE_REWARDS = rewards; v3.REWARD_QUEUE = v3.build_reward_queue()
sd.LOOP["post"]["errands"] += 33.6
if housing:
    HOUSING = [(50, 80), (30, 200), (24, 600), (18, 1200)]
    _loop = sd._daily_loop
    def f(world, active_ids):
        _loop(world, active_ids)
        rooms = {t: n for t, n in HOUSING}
        for pid in sorted(active_ids, key=lambda i: -world.residents[i].cash):
            p = world.residents[pid]; floor = v3.recovery_floor(world.cfg, p.q_completed)
            for t, _ in HOUSING:
                if rooms[t] > 0 and p.cash >= floor + 14 * t:
                    rooms[t] -= 1; p.cash -= t - 12; world.general_business_cash += t - 12; break
    sd._daily_loop = f
base = sd.Ext("x", "x", "launch_base", loop="funded", share=0.15, tax=0.20, need_increment=1.0)
res = sd.run_family([base], 4)
for k in ("mint_cum", "j0_paid", "money_start", "money_end", "player_cash_median", "recovery_fund_min"):
    print(k, [round(r[k]) for r in res])
