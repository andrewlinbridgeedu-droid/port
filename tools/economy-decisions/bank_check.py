"""Bank candidate stress test on the existing V3 whole-server model.

Imports V3 read-only through shared_decisions. Uses measured campaign daily payouts,
the source 1,360-copper or candidate 2,400-copper advancement bill, segregated principal
and a finite coupon fund. --earning uses physical food aid instead of cash recovery.
This aggregate server model does not replay individual fights or NPC deaths.
"""
from __future__ import annotations
import argparse
import json
import gzip
from dataclasses import dataclass, replace
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor
import shared_decisions as sd

v3 = sd.v3
BASE_CONFIGS = v3.scenario_configs
BASE_INIT = v3.init_world
BASE_MONEY = v3.World.active_server_money
BASE_LOOP = sd._daily_loop
BASE_SERVICES = v3.process_open_services
BASE_CLAIM = v3.claim_story_rewards
BASE_BASKET = v3.process_protected_basket
MATERIALS = [(17, 260), (20, 340), (23, 480), (30, 280)]

@dataclass(frozen=True)
class Case:
    name: str
    base: str = 'steady_fresh20'
    bonus: int = 0
    risk: int = 0
    repayment_percent: int = 105
    delay: int = 7
    early_exit: bool = False
    protect: bool = True
    unbacked: bool = False
    recovery_fund: int = 960000
    expansion: int = 0
    earned_materials: bool = False

CASE = None
BANK = None

def materials():
    return [(17, 500), (20, 650), (23, 950), (30, 300)] if CASE.earned_materials else MATERIALS


def food_aid(w, day, active_ids, nf, hf, bed):
    # Voucher money is usable ONLY inside the synchronous basket purchase.
    # Unfilled vouchers return to the same finite recovery fund immediately.
    grants = {}
    if CASE.earned_materials:
        for pid in active_ids:
            p = w.residents[pid]
            if p.cash < w.cfg.basket_price and w.recovery_fund_cash >= w.cfg.basket_price:
                grants[pid] = p.cash
                p.cash += w.cfg.basket_price
                w.recovery_fund_cash -= w.cfg.basket_price
    out = BASE_BASKET(w, day, active_ids, nf, hf, bed)
    for pid, before in grants.items():
        p = w.residents[pid]
        if p.cash == before + w.cfg.basket_price:
            p.cash -= w.cfg.basket_price
            w.recovery_fund_cash += w.cfg.basket_price
        else:
            assert p.cash == before
            BANK['food_aid_paid'] += w.cfg.basket_price
            BANK['food_aid_baskets'] += 1
    return out

def init_bank(cfg, seed, mature_initial=False):
    global BANK
    w = BASE_INIT(cfg, seed, mature_initial)
    # Cover every possible fresh identity this year, including daily replacements.
    budget = CASE.bonus * (cfg.resident_cap + cfg.days * cfg.replacements_per_day)
    assert budget <= w.npc_financial_cash
    w.npc_financial_cash -= budget
    BANK = dict(coupon=budget, budget=budget, custody=0, buyer_escrow=0,
                contracts=[], deposit_users=set(), risk_users=set(), materials={},
                deposit_paid=0, risk_principal=0, risk_returned=0, deposit_principal=0,
                redeemed=0, denied_budget=0, denied_reserve=0, minimum_coverage=1.,
                food_aid_paid=0, food_aid_baskets=0, advance_paid=0, combat_cost_paid=0, combat_cost_due=0, j0_avoided=0, minted_bonus=0, settled=0)
    return w

def server_money(w):
    return BASE_MONEY(w) + BANK['coupon'] + BANK['custody'] + BANK['buyer_escrow']

def principal(p, kind=None):
    return sum(c['principal'] for c in BANK['contracts'] if c['p'].pid == p.pid and (kind is None or kind == c['kind']))

def pay_player(w, p, amount):
    # All departures archive in these shared-only scenarios; contracts survive churn.
    assert p.pid in w.residents or p.pid in w.dormant
    p.cash += amount

def redeem(w, p, need):
    if p.cash >= need:
        return
    c = next((c for c in BANK['contracts'] if c['p'].pid == p.pid and c['kind'] == 'deposit'), None)
    if c:
        BANK['contracts'].remove(c)
        BANK['custody'] -= c['principal']
        pay_player(w, p, c['principal'])
        BANK['redeemed'] += 1

def settle(w):
    for c in list(BANK['contracts']):
        if c['due'] > sd.TODAY:
            continue
        p, amount = c['p'], c['principal']
        if c['kind'] == 'deposit':
            BANK['custody'] -= amount
            pay_player(w, p, amount)
            if CASE.unbacked:
                w.mint_to_player(p, CASE.bonus)
                BANK['minted_bonus'] += CASE.bonus
            else:
                assert BANK['coupon'] >= CASE.bonus
                BANK['coupon'] -= CASE.bonus
                pay_player(w, p, CASE.bonus)
            BANK['deposit_paid'] += CASE.bonus
        else:
            paid = amount * CASE.repayment_percent // 100
            # The buyer reserved a 115% procurement budget at signing. Unused budget
            # returns to the buyer; production spending already reached suppliers.
            BANK['buyer_escrow'] -= c['buyer']
            pay_player(w, p, paid)
            fee = amount * 2 // 100 if paid > amount else 0
            merchant_profit = amount * 115 // 100 - paid - fee if paid > amount else 0
            w.npc_financial_cash += fee
            w.general_business_cash += merchant_profit
            w.industrial_customer_cash += c['buyer'] - paid - fee - merchant_profit
            BANK['risk_returned'] += paid
        BANK['contracts'].remove(c)
        BANK['settled'] += 1
    owed = sum(c['principal'] for c in BANK['contracts'] if c['kind'] == 'deposit')
    assert BANK['custody'] == owed
    assert min(BANK['coupon'], BANK['custody'], BANK['buyer_escrow']) >= 0

def advance(w, p):
    owned = BANK['materials'].setdefault(p.pid, set())
    for q, cost in materials():
        if p.q_completed < q or q in owned:
            continue
        if p.cash + principal(p, 'deposit') >= cost + 66:
            redeem(w, p, cost + 66)
            p.cash -= cost
            w.general_business_cash += cost
            owned.add(q)
            BANK['advance_paid'] += cost

def reserve(p):
    owned = BANK['materials'].get(p.pid, set())
    spent = sum(cost for q, cost in materials() if q in owned)
    next_cost = next((cost for q, cost in materials() if q <= p.q_completed and q not in owned), 0)
    planned = sum(cost for _, cost in materials()) * p.q_completed // 30
    if CASE.earned_materials:
        planned = 0
        previous = 0
        for gate, price in materials():
            if p.q_completed < gate:
                planned += price * max(0, p.q_completed - previous) // (gate - previous)
                break
            planned += price
            previous = gate
    return 66 + max(next_cost, max(0, planned - spent) if CASE.protect else next_cost)

def bank_loop(w, active_ids):
    BASE_LOOP(w, active_ids)
    settle(w)
    for pid in active_ids:
        p = w.residents[pid]
        advance(w, p)
        if CASE.bonus and pid not in BANK['deposit_users'] and p.cash >= 72:
            p.cash -= 60
            BANK['custody'] += 60
            BANK['deposit_principal'] += 60
            BANK['deposit_users'].add(pid)
            BANK['contracts'].append(dict(p=p, kind='deposit', principal=60, due=sd.TODAY + 3))
        if CASE.early_exit:
            redeem(w, p, p.cash + 1)
        if CASE.risk and p.q_completed >= 5 and pid not in BANK['risk_users']:
            limit = 160 if p.q_completed >= 16 else 100
            if principal(p) + CASE.risk > limit or p.cash - CASE.risk < reserve(p):
                BANK['denied_reserve'] += 1
                continue
            buyer = CASE.risk * 115 // 100
            if w.industrial_customer_cash < buyer:
                BANK['denied_budget'] += 1
                continue
            p.cash -= CASE.risk
            w.general_business_cash += CASE.risk  # real production cost; a loss is not a money sink
            w.industrial_customer_cash -= buyer
            BANK['buyer_escrow'] += buyer
            BANK['contracts'].append(dict(p=p, kind='risk', principal=CASE.risk, buyer=buyer, due=sd.TODAY + CASE.delay))
            BANK['risk_users'].add(pid)
            BANK['risk_principal'] += CASE.risk

def j0(w, active_ids):
    bank_loop(w, active_ids)
    if CASE.earned_materials:
        sd.STATS['below_floor_share'].append(sum(w.residents[pid].cash + principal(w.residents[pid]) < 66 for pid in active_ids) / max(1, len(active_ids)))
        return 0, 0
    tasks = paid = below = 0
    for pid in active_ids:
        p = w.residents[pid]
        floor = v3.recovery_floor(w.cfg, p.q_completed)
        # Do not drop the recovery line before the actual material/ritual bill is paid.
        if CASE.protect and p.q_completed >= 30 and len(BANK['materials'].get(pid, set())) < 4:
            floor = max(600, floor)
        assets = p.cash + principal(p)
        below += assets < floor
        if p.cash < floor <= assets:
            BANK['j0_avoided'] += 1
        amount = min(40, max(0, floor + 40 - assets)) if CASE.protect else (40 if assets < floor else 0)
        if amount and w.recovery_fund_cash >= amount:
            w.recovery_fund_cash -= amount; p.cash += amount
            w.cumulative_j0_paid += amount; tasks += 1; paid += amount
    sd.STATS['below_floor_share'].append(below / max(1, len(active_ids)))
    return tasks, paid

def services(w, active_ids):
    # Prevent discretionary purchases spending the planned advancement budget.
    held = {}
    if CASE.protect:
        for pid in active_ids:
            p = w.residents[pid]
            held[pid] = min(p.cash, max(0, reserve(p) - w.cfg.discretionary_buffer))
            p.cash -= held[pid]
    out = BASE_SERVICES(w, active_ids)
    for pid, amount in held.items():
        w.residents[pid].cash += amount
    return out

def claim(w, p):
    # Campaign purchases, medicines and repairs are coupled to entitlement progress.
    # V3 still estimates Q from its receipt queue; this is not a second combat proof.
    before = p.reward_cursor
    out = BASE_CLAIM(w, p)
    due = (p.reward_cursor - before) * sd.LOOP['campaign_cost_per_receipt']
    p.bank_cost_pending = getattr(p, 'bank_cost_pending', 0.) + due
    BANK['combat_cost_due'] += due
    paid = min(max(0, p.cash - 66), int(p.bank_cost_pending))
    p.bank_cost_pending -= paid
    p.cash -= paid; w.general_business_cash += paid
    BANK['combat_cost_paid'] += paid
    return out

def run_job(job):
    global CASE
    CASE, seed, days, rates = job
    sd.LOOP = rates
    def configs():
        out = {}
        for k, cfg in BASE_CONFIGS().items():
            # User's shared-only decision: no imported saves, all newcomers fresh.
            # Reallocate the recovery stress budget from existing financial money.
            extra = CASE.recovery_fund - cfg.recovery_fund_cash
            out[k] = replace(cfg, days=days, fresh_share=1., departing_transfer_share=0.,
                             recovery_fund_cash=CASE.recovery_fund,
                             general_business_cash=cfg.general_business_cash-min(600000, extra),
                             npc_financial_cash=cfg.npc_financial_cash-max(0, extra-600000),
                             expansion_nonfuel_capacity=CASE.expansion or cfg.expansion_nonfuel_capacity,
                             expansion_cost=CASE.expansion * 120 if CASE.expansion else cfg.expansion_cost)
        return out
    v3.scenario_configs = configs
    rewards = list(v3.MAINLINE_REWARDS)
    # Each worker can run more than one case; update exactly once.
    if rewards[2] == ORIGINAL_REWARDS[2]:
        rewards[2] += 100; rewards[4] += 100
        for i in range(25, 30): rewards[i] -= 40
        v3.MAINLINE_REWARDS = rewards; v3.REWARD_QUEUE = v3.build_reward_queue()
    v3.init_world = init_bank
    v3.World.active_server_money = server_money
    v3.process_shared_j0 = j0
    v3.process_open_services = services
    v3.claim_story_rewards = claim
    v3.process_protected_basket = food_aid
    ext = sd.Ext(CASE.name, 'bank', CASE.base, loop='funded', share=1., tax=.2, need_increment=1.)
    out = sd.run_one((ext, seed))
    out['bank'] = {k: v for k, v in BANK.items() if k not in ('contracts', 'deposit_users', 'risk_users', 'materials')}
    out['bank'].update(deposit_accounts=len(BANK['deposit_users']), risk_accounts=len(BANK['risk_users']),
                       open_contracts=len(BANK['contracts']),
                       finished_ritual_accounts=sum(len(x) == 4 for x in BANK['materials'].values()))
    out['candidate_rules'] = dict(materials=materials(), cash_recovery=not CASE.earned_materials)
    out['source_audit_pass'] = not BANK['minted_bonus'] and out['unbacked_minted'] == 0
    return out

ORIGINAL_REWARDS = tuple(v3.MAINLINE_REWARDS)

def campaign_rates(path):
    p = Path(path)
    if p.exists():
        rows = json.loads(p.read_text())
    else:
        with gzip.open(str(p) + '.gz', 'rt') as f:
            rows = json.load(f)
    r = next(r for r in rows if r['policy'] == 'all' and r['profile'] == 'medium' and r['startOffset'] == 0 and r['bankExperiment']['scenario']['name'].endswith('_none'))
    day = r['bankExperiment']['storyDay']
    src = r['copperBySource']
    chapter = {name: src.get(source, 0) / day for name, source in [('orders','workshop'),('errands','errand'),('remnants','remnant'),('events','event')]}
    # Unit base-stock cost is about 42–50% of order prices before city effects.
    # Attribute 50% to sales here; all other measured campaign spending is charged
    # separately with entitlement progress, avoiding double-counting self-used goods.
    stock = chapter['orders'] * .5  # candidate unit-stock allowance, 42–50% before city surcharge
    post = dict(chapter, orders=9., remnants=4.5, events=0., errands=chapter['errands'] + 5.04)
    all_spending = 180 + sum(src.values()) - r['copper']
    other = all_spending - r['bankExperiment']['advancementSpent'] - r['bankExperiment']['livingPaid'] - stock * day
    assert other >= 0
    return dict(chapter=chapter, chapter_stock=stock, post=post,
                post_stock=4.5, source_days=day,
                campaign_cost_total=other, campaign_cost_per_receipt=other / len(v3.REWARD_QUEUE))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--campaign', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--days', type=int, default=365)
    ap.add_argument('--seeds', default='1,2,3')
    ap.add_argument('--workers', type=int, default=3)
    ap.add_argument('--cases', default='')
    ap.add_argument('--earning', action='store_true')
    args = ap.parse_args()
    dest = Path(args.out); dest.mkdir(parents=True, exist_ok=True)
    rates = campaign_rates(args.campaign)
    cases = [Case('none'), Case('original_coupon3', bonus=3, protect=False),
             Case('coupon12', bonus=12), Case('early_redemption', bonus=12, early_exit=True),
             Case('risk80_profit', bonus=12, risk=80), Case('risk80_delay', bonus=12, risk=80, delay=10),
             Case('risk80_loss20pct', bonus=12, risk=80, repayment_percent=80),
             Case('risk80_total_loss', bonus=12, risk=80, repayment_percent=0),
             Case('risk160_total_loss', bonus=12, risk=160, repayment_percent=0),
             Case('supply_half_repaired', base='supply_half_90_repair', bonus=12, risk=80),
             Case('supply_half_unrepaired', base='supply_half_90_no_repair', bonus=12, risk=80),
             Case('negative_unbacked_coupon', bonus=12, unbacked=True),
             Case('loss_fund1680k', bonus=12, risk=80, repayment_percent=0, recovery_fund=1680000),
             Case('repair2000', base='supply_half_90_repair', bonus=12, risk=80, expansion=2000),
             Case('combined_loss_and_supply', base='supply_half_90_repair', bonus=12, risk=80,
                  repayment_percent=0, recovery_fund=1680000, expansion=2000)]
    if args.cases:
        cases = [c for c in cases if c.name in args.cases.split(',')]
    if args.earning:
        cases = [replace(c, earned_materials=True, recovery_fund=960000) for c in cases]
    jobs = [(c, seed, args.days, rates) for c in cases for seed in map(int, args.seeds.split(','))]
    results = []
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        for row in pool.map(run_job, jobs):
            results.append(row)
            print(row['ext']['name'], row['seed'], 'L1/L2/L3', row['L1'], row['L2_strict'], row['L3'], 'peak', round(row['peak_index'], 4), 'J0', row['j0_paid'], flush=True)
            (dest/'results.json').write_text(json.dumps(dict(days=args.days, rates=rates, results=results), ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
