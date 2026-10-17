"""Direct-funded food aid: cannot become copper for advancement or bank investment."""
import sys
from dataclasses import replace
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'tools/economy-decisions'))
import bank_check as b
b.CASE = b.Case('aid-unit', earned_materials=True)
b.sd.EXT = b.sd.Ext('aid-unit', 'bank', 'steady_fresh20', loop='funded', share=1., tax=.2, need_increment=1.)
cfg = replace(b.BASE_CONFIGS()['steady_fresh20'], player_need_increment=1.)
for supply, expected_paid in [(20000, 12), (0, 0)]:
    w = b.init_bank(cfg, 1)
    pid = next(iter(w.residents))
    p = w.residents[pid]
    p.cash = 7
    p.need = 0
    w.nonfuel_reserve = w.imported_nonfuel_stock = 0
    w.household_fuel_reserve_kg = w.imported_household_fuel_stock_kg = 0
    money = b.server_money(w)
    fund = w.recovery_fund_cash
    b.food_aid(w, 1, [pid], supply, supply, supply)
    assert p.cash == 7
    assert fund - w.recovery_fund_cash == expected_paid
    assert b.BANK['food_aid_paid'] == expected_paid
    assert b.server_money(w) == money
    assert p.need == (0 if expected_paid else 1)
print('PASS food voucher pays only fulfilled physical basket; unfilled voucher refunded; no transferable aid; money conserved')
