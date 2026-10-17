"""Check only the proposal's calendar arithmetic and isolated cash examples.

This is not a progression simulator, a bank implementation, or an inflation test.
Run from any directory with Python 3. No player data is read or modified.
"""

import json
from fractions import Fraction
from pathlib import Path


def opening_day(mission):
    return max(1, mission - 2)


def tower_day(floor):
    gate = 7 if floor <= 10 else 10 if floor <= 30 else 13 if floor <= 50 else 16 if floor <= 70 else 20
    return max(opening_day(gate), (floor + 3) // 4)


def split_integer(total, shares):
    exact = [Fraction(total * share, sum(shares)) for share in shares]
    paid = [int(value) for value in exact]
    order = sorted(range(len(shares)), key=lambda i: (-(exact[i] - paid[i]), i))
    for index in order[:total - sum(paid)]:
        paid[index] += 1
    assert sum(paid) == total
    return paid


def note_example(customer_payment):
    # The customer's 115 exists at the beginning, including in the failure paths.
    initial = {"investor": 100, "customer": 115, "project": 0, "suppliers": 0, "bank": 0}
    cash = dict(initial)

    def transfer(sender, recipient, amount):
        assert 0 <= amount <= cash[sender]
        cash[sender] -= amount
        cash[recipient] += amount

    transfer("investor", "project", 100)
    transfer("project", "suppliers", 100)
    transfer("customer", "project", customer_payment)
    transfer("project", "investor", min(105, cash["project"]))
    if customer_payment >= 107:
        transfer("project", "bank", 2)
    assert sum(cash.values()) == sum(initial.values())
    return {"customer_payment": customer_payment, "cash": cash, "investor_net": cash["investor"] - 100}


def deposit_example(principal, early=False):
    bonus = principal // 20 * 4
    # Bank service budget is funded before subscription; no interest minting.
    cash = {"wallet": principal, "principal_custody": 0, "bank_service_budget": bonus}
    initial_total = sum(cash.values())
    cash["wallet"] -= principal
    cash["principal_custody"] += principal
    assert cash["principal_custody"] == principal
    cash["principal_custody"] -= principal
    cash["wallet"] += principal
    if not early:
        cash["bank_service_budget"] -= bonus
        cash["wallet"] += bonus
    assert sum(cash.values()) == initial_total
    return {"principal": principal, "early_exit": early, "cash": cash}


def main():
    mission_days = {f"Q{q}": opening_day(q) for q in (1, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 16, 17, 18, 20, 22, 23, 25, 26, 28, 30)}
    tower_days = {f"F{floor}": tower_day(floor) for floor in (10, 30, 50, 70, 90, 100)}
    assert tower_days == {"F10": 5, "F30": 8, "F50": 13, "F70": 18, "F90": 23, "F100": 25}
    old_story = [30] * 5 + [40] * 5 + [50] * 5 + [80] * 5 + [100] * 5 + [120] * 4 + [300]
    proposed_story = old_story.copy()
    for q in (3, 5):
        proposed_story[q - 1] += 100
    for q in range(26, 31):
        proposed_story[q - 1] -= 40
    assert sum(old_story) == sum(proposed_story) == 2280
    assert 180 + 2280 + 1700 + 1060 == 5220
    assert 260 + 340 + 480 + 280 == 1360
    assert 500 + 650 + 950 + 300 == 2400
    assert 5220 - 28 * 12 - 2400 == 2484
    assert 2400 + 336 + 280 - (180 + 2280) == 556
    equity = {str(total): split_integer(total, [80, 320]) for total in (448, 360, 160)}
    assert equity == {"448": [90, 358], "360": [72, 288], "160": [32, 128]}
    contracts = [note_example(payment) for payment in (115, 80, 0)]
    assert [x["investor_net"] for x in contracts] == [5, -20, -100]
    deposits = [deposit_example(p, early) for p in (20, 40, 60) for early in (False, True)]
    checks = {
        "date": "2026-10-13",
        "scope": "候选方案的静态日期、算术、孤立合同现金守恒；不是正式游戏模拟或经济稳定性验证",
        "mission_opening_days": mission_days,
        "tower_earliest_days": tower_days,
        "story_reward_sum_before_and_after": [sum(old_story), sum(proposed_story)],
        "one_time_gross_income": 5220,
        "source_advancement_budget": 1360,
        "candidate_advancement_budget": 2400,
        "minimum_nonstory_income_with_two_basic_relics": 556,
        "basic_living_28_active_days": 336,
        "remaining_before_other_required_costs": 2484,
        "new_customer_bonus_budget_2000_accounts": 24000,
        "new_customer_bonus_budget_9300_accounts": 111600,
        "source_weekly_highland_cost": 350,
        "candidate_weekly_highland_cost": 294,
        "candidate_weekly_highland_premium_vs_basic": 210,
        "sample_daily_stamina": {"street_day": 10 + 15 + 20 + 15 + 15 + 5, "production_day": 20 + 30 + 5 + 25},
        "deposits": deposits,
        "order_note_cash_paths": contracts,
        "equity_distributions_player_then_npc": equity,
        "bank_loan_capacity_fee_outside_equity": 500 - 72,
        "bank_loan_capacity_fee_inside_equity": 500 - 40 - 72,
        "not_verified": ["真实生产工时与需求", "新手连续现金流", "合同失败概率", "全服通胀与缺货", "并发与幂等实现", "真机体验"],
    }
    destination = Path(__file__).with_name("check-results.json")
    destination.write_text(json.dumps(checks, ensure_ascii=False, indent=2) + "\n")
    print(f"Static proposal checks passed. Wrote {destination}")


if __name__ == "__main__":
    main()
