"""Shared-server economy decisions by simulation (user request 2026-09-29).

Built on the Pro V3 daily server model (docs/development/economy-2000-v3-pro-source), imported
read-only and extended through hooks: the daily-loop copper of the new daily systems, local
wealth brought into the shared server, the six underground commissions, an unbacked-mint
negative control, and a price-scale factor. Acceptance lines and decision rules are fixed in
this file before any run (see RULES); the report prints them first.

This is a design model, not game code and not proof that a live server cannot inflate.

    python3 tools/economy-decisions/shared_decisions.py --out <dir> [--workers 4]
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import random
import statistics
import sys
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass, field, replace, asdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V3_DIR = ROOT / "docs/development/economy-2000-v3-pro-source"
sys.path.insert(0, str(V3_DIR))
import mistport_server_economy_sim_v3 as v3  # noqa: E402

SEEDS = [1, 2, 3, 4, 5]

# ---------------------------------------------------------------------------
# Inputs from the rest of the project
# ---------------------------------------------------------------------------


def daily_loop_rates() -> dict:
    """Copper per active day from the new daily systems, taken from the human-pace campaign
    (typical pace, all content): chapter one, then afterwards (orders keep their 60-copper
    daily budget, errands continue, one remnant case a day, chapter-one events are over)."""
    runs = json.loads((ROOT / "docs/development/human-timing-20260929/raw/runs.json").read_text())
    r = next(x for x in runs if x["profile"] == "typical" and x["policy"] == "all" and x["startOffset"] == 0)
    days, src = r["days"], r["copperBySource"]
    sales = src.get("workshop", 0)
    stock_ratio = r["workshop"]["baseStockCopper"] / max(1, sales)
    chapter = {"orders": sales / days, "errands": src.get("errand", 0) / days,
               "remnants": src.get("remnant", 0) / days, "events": src.get("event", 0) / days}
    post = {"orders": 60.0, "errands": chapter["errands"], "remnants": 30.0, "events": 0.0}
    return {"chapter": chapter, "chapter_stock": chapter["orders"] * stock_ratio,
            "post": post, "post_stock": post["orders"] * stock_ratio, "source_days": days}


LOOP = daily_loop_rates()
UNDERGROUND_COPPER = 560  # U01–U06, one-off (ECONOMY.md), paid when the chapter is finished

# Local saves at the shared launch: half the launch cohort brings a single-player save.
# End-of-chapter balances from the human-pace campaign are 2,800–3,800 for all-content players
# and about 420 for wall-only players; grinders hold more. Lognormal, median 2,000, cap 12,000.
LOCAL_SAVE_SHARE = 0.5
LOCAL_BALANCE_MEDIAN = 2000
LOCAL_BALANCE_SIGMA = 0.8
LOCAL_BALANCE_CAP = 12000

# ---------------------------------------------------------------------------
# Experiment definition
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Ext:
    name: str
    family: str
    base: str = "launch_base"
    # Daily-loop copper in the shared server: none | mint (single-player semantics) | funded
    loop: str = "none"
    # Share of the single-player daily-loop copper that the shared server pays (1 = same as local).
    share: float = 1.0
    # funded: the city budget (treasury) pays every channel; it collects this share of each
    # day's basket sales (from NPC households) and open-service sales (from business).
    tax: float = 0.0
    import_cap: int = 0
    # Local copper counts at this rate when it enters the shared server (1 = one for one).
    import_rate: float = 1.0
    need_increment: float | None = None
    unbacked_per_active: int = 0
    underground: bool = False
    scale: float = 1.0
    control: bool = False


# Per-process state (each run happens in one worker process).
EXT: Ext | None = None
STATS: dict = {}
WORLD = None
LAST_SERVICE_SPEND = 0
LAST_BASKET_SALES = 0
TODAY = 0

_orig_init_world = v3.init_world
_orig_j0 = v3.process_shared_j0
_orig_services = v3.process_open_services
_orig_basket = v3.process_protected_basket
_orig_claim = v3.claim_story_rewards
_orig_fresh = v3.World.create_fresh_entitlement
_orig_validate = v3.Config.validate
IN_INIT = False


def _validate(self):
    if EXT is not None and EXT.scale != 1.0:
        assert abs(self.nonfuel_price + self.household_fuel_price_per_kg * self.household_fuel_per_basket_kg
                   + self.bed_price - self.basket_price) < 1e-6
        return
    _orig_validate(self)


def _init_world(cfg, seed, mature_initial=False):
    global IN_INIT, WORLD
    IN_INIT = True
    try:
        w = _orig_init_world(cfg, seed, mature_initial)
    finally:
        IN_INIT = False
    WORLD = w
    return w


def _fresh(self, p, instant_full=False):
    out = _orig_fresh(self, p, instant_full)
    if IN_INIT and EXT.import_cap > 0 and self.rng.random() < LOCAL_SAVE_SHARE:
        balance = min(LOCAL_BALANCE_CAP, int(self.rng.lognormvariate(math.log(LOCAL_BALANCE_MEDIAN), LOCAL_BALANCE_SIGMA)))
        amount = int(min(EXT.import_cap, balance) * EXT.import_rate)
        self.mint_to_player(p, amount)
        STATS["import_minted"] += amount
    return out


def _claim(world, p):
    was = p.entitlement_completed
    out = _orig_claim(world, p)
    if EXT.underground and not was and p.entitlement_completed:
        world.mint_to_player(p, UNDERGROUND_COPPER)
        STATS["underground_minted"] += UNDERGROUND_COPPER
    return out


def _pay(world, account: str, p, amount: int) -> int:
    have = getattr(world, account)
    paid = max(0, min(have, amount))
    if paid:
        setattr(world, account, have - paid)
        p.cash += paid
    return paid


def _daily_loop(world, active_ids):
    global TODAY
    TODAY += 1
    ext = EXT
    if ext.tax > 0:
        # The city budget's income: a share of yesterday's basket and open-service sales.
        from_households = min(world.npc_household_cash, int(LAST_BASKET_SALES * ext.tax))
        from_business = min(world.general_business_cash, int(LAST_SERVICE_SPEND * ext.tax))
        world.npc_household_cash -= from_households
        world.general_business_cash -= from_business
        world.treasury_general_cash += from_households + from_business
        STATS["levy_moved"] += from_households + from_business
        STATS["levy_today"] = (from_households, from_business)
    if ext.unbacked_per_active > 0:
        for pid in active_ids:
            world.mint_to_player(world.residents[pid], ext.unbacked_per_active)
            STATS["unbacked_minted"] += ext.unbacked_per_active
    if ext.loop == "none":
        _recycle(world, ext)
        return
    order = list(active_ids)
    world.rng.shuffle(order)
    for pid in order:
        p = world.residents[pid]
        chapter = p.origin == "fresh" and not p.entitlement_completed
        rates = LOOP["chapter"] if chapter else LOOP["post"]
        stock_rate = (LOOP["chapter_stock"] if chapter else LOOP["post_stock"]) / max(1e-9, rates["orders"])
        for channel, amount in rates.items():
            due = int(round(amount * ext.share))
            if due <= 0:
                continue
            STATS["due"][channel] += due
            if ext.loop == "mint":
                world.mint_to_player(p, due)
                paid = due
                STATS["loop_minted"] += due
            else:
                paid = _pay(world, "treasury_general_cash", p, due)
                if paid < due:
                    STATS["short_days"][channel].add(TODAY)
                    if STATS["account_empty_day"].get("treasury_general_cash") is None:
                        STATS["account_empty_day"]["treasury_general_cash"] = TODAY
            STATS["paid"][channel] += paid
            if channel == "orders" and paid > 0:
                # Goods for the orders need base stock bought from NPC producers, whose income
                # reaches NPC households as in V3's basket closure. Only for orders actually paid.
                stock = int(min(p.cash, round(paid * stock_rate)))
                p.cash -= stock
                world.npc_household_cash += stock
                STATS["stock_paid"] += stock
    _recycle(world, ext)


def _recycle(world, ext):
    # The city budget does not hoard: whatever it holds above its opening reserve after paying
    # today's players is refunded the same day to the accounts it was levied from, in today's
    # proportions. The tax rate is therefore a cap on the daily levy, not a transfer between
    # NPC accounts. (Without the refund a levy larger than the payouts drains household cash and
    # the basket stops selling; refunding everything to households instead would move business
    # cash to households and make a higher tax look better.)
    if ext.tax <= 0:
        return
    surplus = world.treasury_general_cash - world.cfg.treasury_general_cash
    if surplus > 0:
        households, business = STATS["levy_today"]
        to_households = surplus if households + business == 0 else int(surplus * households / (households + business))
        world.treasury_general_cash -= surplus
        world.npc_household_cash += to_households
        world.general_business_cash += surplus - to_households
        STATS["recycled"] += surplus


def _j0(world, active_ids):
    _daily_loop(world, active_ids)
    # Players below the recovery floor today (before the fiscal J0 pays them).
    below = sum(1 for pid in active_ids if world.residents[pid].cash < v3.recovery_floor(world.cfg, world.residents[pid].q_completed))
    STATS["below_floor_share"].append(below / max(1, len(active_ids)))
    return _orig_j0(world, active_ids)


def _services(world, active_ids):
    global LAST_SERVICE_SPEND
    out = _orig_services(world, active_ids)
    LAST_SERVICE_SPEND = out["open_service_spent"]
    return out


def _basket(world, day, active_ids, nf, hf, bed):
    global LAST_BASKET_SALES
    out = _orig_basket(world, day, active_ids, nf, hf, bed)
    LAST_BASKET_SALES = out["total_basket_payment"]
    return out


v3.Config.validate = _validate
v3.init_world = _init_world
v3.World.create_fresh_entitlement = _fresh
v3.claim_story_rewards = _claim
v3.process_shared_j0 = _j0
v3.process_open_services = _services
v3.process_protected_basket = _basket


def scaled_config(cfg, k: float):
    """Multiply every NPC price, cost, cash balance and industry value by k; player rewards,
    J0 pay and recovery floors (game data) stay as they are."""
    if k == 1.0:
        return cfg
    ints = lambda x: int(round(x * k))
    return replace(
        cfg,
        basket_price=ints(cfg.basket_price), nonfuel_price=ints(cfg.nonfuel_price),
        household_fuel_price_per_kg=ints(cfg.household_fuel_price_per_kg), bed_price=ints(cfg.bed_price),
        open_service_base_price=cfg.open_service_base_price * k,
        nonfuel_domestic_unit_cost=ints(cfg.nonfuel_domestic_unit_cost), nonfuel_import_unit_cost=ints(cfg.nonfuel_import_unit_cost),
        household_fuel_domestic_cost_per_kg=ints(cfg.household_fuel_domestic_cost_per_kg),
        household_fuel_import_cost_per_kg=ints(cfg.household_fuel_import_cost_per_kg),
        npc_household_cash=ints(cfg.npc_household_cash), other_producer_cash=ints(cfg.other_producer_cash),
        bike_industry_cash=ints(cfg.bike_industry_cash), pump_industry_cash=ints(cfg.pump_industry_cash),
        general_business_cash=ints(cfg.general_business_cash), transport_customer_cash=ints(cfg.transport_customer_cash),
        industrial_customer_cash=ints(cfg.industrial_customer_cash), npc_financial_cash=ints(cfg.npc_financial_cash),
        treasury_general_cash=ints(cfg.treasury_general_cash), stabilizer_cash=ints(cfg.stabilizer_cash),
        recovery_fund_cash=cfg.recovery_fund_cash, system_emergency_cash=ints(cfg.system_emergency_cash),
        transport_service_revenue_per_day=ints(cfg.transport_service_revenue_per_day),
        industrial_service_revenue_per_day=ints(cfg.industrial_service_revenue_per_day),
        bike_sale_price=ints(cfg.bike_sale_price), bike_variable_cost=ints(cfg.bike_variable_cost),
        bike_sector_setup_cost_once=ints(cfg.bike_sector_setup_cost_once), bike_cycle_maintenance=ints(cfg.bike_cycle_maintenance),
        pump_sale_price=ints(cfg.pump_sale_price), pump_variable_cost=ints(cfg.pump_variable_cost),
        pump_sector_setup_cost_once=ints(cfg.pump_sector_setup_cost_once), pump_cycle_maintenance=ints(cfg.pump_cycle_maintenance),
        bike_project_cost_10=ints(cfg.bike_project_cost_10), pump_project_cost_2=ints(cfg.pump_project_cost_2),
        foreign_bike_budget_initial=ints(cfg.foreign_bike_budget_initial), foreign_pump_budget_initial=ints(cfg.foreign_pump_budget_initial),
        expansion_cost=ints(cfg.expansion_cost),
    )


# ---------------------------------------------------------------------------
# Acceptance lines (candidates, fixed before running)
# ---------------------------------------------------------------------------

LINES = {
    "L1": "保护篮子：非冲击年份 ≥95% 的天履约 ≥99%、最低 ≥95%；冲击年份最低 ≥85%，冲击结束后 30 天内回到 ≥99%",
    "L2_primary": "开放市场价格：峰值 ≤1.5 倍；相邻 30 天均价变化 ≤20%；第 31–60 天到最后 30 天累计 ≤+25%",
    "L2_strict": "开放市场价格（严格）：峰值 ≤1.25 倍；相邻 30 天均价变化 ≤15%；累计 ≤+15%",
    "L3": "资金：逐日货币恒等（V3 内置断言）；恢复基金一年内不用光；稳价基金不低于期初 25%",
}


def metrics(rows, cfg, ext) -> dict:
    idx = [float(r["open_service_price_index"]) for r in rows]
    fill = [float(r["protected_fulfillment_rate"]) for r in rows]
    windows = [statistics.mean(idx[i:i + 30]) for i in range(0, len(idx) - 29, 30)]
    changes = [abs(b / a - 1) for a, b in zip(windows, windows[1:]) if a > 0]
    annual = windows[-1] / windows[1] - 1 if len(windows) > 2 and windows[1] > 0 else None
    shock = cfg.nonfuel_shock_start < 999999
    recovery_days = None
    if shock:
        after = [r for r in rows if int(r["day"]) > cfg.nonfuel_shock_end]
        back = next((int(r["day"]) for r in after if float(r["protected_fulfillment_rate"]) >= 0.99), None)
        recovery_days = back - cfg.nonfuel_shock_end if back is not None else None
    fund = [float(r["recovery_fund_cash"]) for r in rows]
    stab = [float(r["stabilizer_cash"]) for r in rows]
    money = [float(r["active_server_money"]) for r in rows]
    players = list(WORLD.residents.values())
    cash = sorted(p.cash for p in players)
    due = sum(STATS["due"].values())
    paid = sum(STATS["paid"].values())
    m = {
        "peak_index": max(idx), "max_30d_change": max(changes) if changes else 0.0, "annual_change": annual,
        "fill_min": min(fill), "fill_share_99": sum(1 for f in fill if f >= 0.99) / len(fill),
        "shock": shock, "recovery_days": recovery_days,
        "recovery_fund_min": min(fund), "recovery_fund_end": fund[-1], "j0_paid": float(rows[-1]["j0_paid_cum"]),
        "stabilizer_min_share": min(stab) / max(1.0, stab[0] if stab[0] > 0 else 1.0),
        "money_start": money[0], "money_end": money[-1], "money_growth": money[-1] / money[0] - 1,
        "mint_cum": float(rows[-1]["mint_cum"]),
        "player_cash_p10": cash[len(cash) // 10], "player_cash_median": cash[len(cash) // 2],
        "below_floor_share": statistics.mean(STATS["below_floor_share"]) if STATS["below_floor_share"] else 0.0,
        "loop_due": due, "loop_paid": paid, "loop_paid_share": paid / due if due else None,
        "loop_paid_by_channel": dict(STATS["paid"]), "loop_due_by_channel": dict(STATS["due"]),
        "loop_short_days": {k: len(v) for k, v in STATS["short_days"].items()},
        "account_empty_day": dict(STATS["account_empty_day"]),
        "loop_minted": STATS["loop_minted"], "import_minted": STATS["import_minted"],
        "underground_minted": STATS["underground_minted"], "unbacked_minted": STATS["unbacked_minted"],
        "levy_moved": STATS["levy_moved"], "recycled": STATS["recycled"], "stock_paid": STATS["stock_paid"],
    }
    m["L1"] = (m["fill_min"] >= 0.85 and recovery_days is not None and recovery_days <= 30) if shock else \
        (m["fill_share_99"] >= 0.95 and m["fill_min"] >= 0.95)
    m["L2_primary"] = m["peak_index"] <= 1.5 and m["max_30d_change"] <= 0.20 and (annual is None or annual <= 0.25)
    m["L2_strict"] = m["peak_index"] <= 1.25 and m["max_30d_change"] <= 0.15 and (annual is None or annual <= 0.15)
    m["L3"] = m["recovery_fund_min"] > 0 and m["stabilizer_min_share"] >= 0.25
    return m


def run_one(job):
    global EXT, STATS, LAST_SERVICE_SPEND, LAST_BASKET_SALES, TODAY
    ext, seed = job
    EXT = ext
    STATS = {"due": {}, "paid": {}, "short_days": {}, "account_empty_day": {}, "loop_minted": 0, "import_minted": 0,
             "underground_minted": 0, "unbacked_minted": 0, "levy_moved": 0, "levy_today": (0, 0), "recycled": 0, "stock_paid": 0, "below_floor_share": []}
    for ch in ("orders", "errands", "remnants", "events"):
        STATS["due"][ch] = 0; STATS["paid"][ch] = 0; STATS["short_days"][ch] = set()
    LAST_SERVICE_SPEND = 0
    LAST_BASKET_SALES = 0
    TODAY = 0
    cfg = v3.scenario_configs()[ext.base]
    if ext.need_increment is not None:
        cfg = replace(cfg, player_need_increment=ext.need_increment)
    cfg = scaled_config(cfg, ext.scale)
    rows, _ = v3.run_simulation(ext.name, cfg, seed)
    m = metrics(rows, cfg, ext)
    return {"ext": asdict(ext), "seed": seed, **m}


# ---------------------------------------------------------------------------
# Experiment families and decision rules (fixed before running)
# ---------------------------------------------------------------------------

NORMAL_BASES = ["launch_base", "steady_fresh20"]


SHARES = (1.0, 0.5, 0.25, 0.15, 0.1, 0.05)
TAXES = (0.02, 0.05, 0.1, 0.2, 0.3)


def family_funding(need_increment=None, family="funding"):
    out = []
    tag = "" if need_increment is None else f"·玩家篮子{need_increment:g}"
    for base in NORMAL_BASES:
        out.append(Ext(f"{base}{tag}·无每日玩法", family, base, need_increment=need_increment))
        out.append(Ext(f"{base}{tag}·照单机发币", family, base, loop="mint", need_increment=need_increment))
        for share in SHARES:
            for tax in TAXES:
                out.append(Ext(f"{base}{tag}·城市预算付{int(share*100)}%·税{int(tax*100)}%", family, base, loop="funded",
                               share=share, tax=tax, need_increment=need_increment))
    return out


def pick_funding(results):
    """D1's rule: among funded (share, tax) pairs that pass L1, L2_primary and L3 in every run of
    both normal bases with at least 95% paid on average, the highest share, then the lowest tax."""
    combos = {}
    for runs in group(results).values():
        ext = runs[0]["ext"]
        if ext["loop"] == "funded":
            combos.setdefault((ext["share"], ext["tax"]), []).append(runs)
    best = None
    for (share, tax), groups in combos.items():
        if len(groups) != len(NORMAL_BASES):
            continue
        runs = [r for g in groups for r in g]
        paid = statistics.mean(r["loop_paid_share"] or 0 for r in runs)
        if all(r["L1"] and r["L2_primary"] and r["L3"] for r in runs) and paid >= 0.95:
            if best is None or (share, -tax) > (best[0], -best[1]):
                best = (share, tax, paid)
    return best


RULES = {
    "D1": "每日玩法的铜：城市预算按税率从 NPC 基础消费和开放服务消费收钱来付。在两个正常年份、5 个种子都满足 L1、L2_primary、L3，且平均实付 ≥95%（玩家看到的委托基本都有预算）的组合里，选付出比例（相对单机）最高的；并列时选税率最低的。照单机发币只作对照。",
    "D2": "本地财富带入：在选定的 D1 方案下，取 L2_primary 仍在 5 个种子都通过的最大上限（0/500/1000/2000/4000/无上限）。",
    "D3": "保护篮子覆盖：玩家每活跃日累积 0/0.25/0.5/1 份需求，选正常年份与“修复的供给减半”都满足 L1 的最大覆盖；未修复的冲击只报告缺口。",
    "D4": "24/12 标尺：按单机全额（付 100%）、D1 的税率，看 NPC 价格与资金整体乘 k（1、2、4、8、16）时哪一档能在两个正常年份都过 L1、L2_primary、L3 且实付 ≥95%。若 D1 已能付全额则保留 24/12；否则把“付几成”与“乘几倍”两种做法并列给用户选。",
    "D5": "验收线：若所有正常情景都过 L2_strict 且所有反例都不过，采用严格线；否则若正常全过 L2_primary、反例全不过，采用主线；否则报告哪条线没有区分力。",
    "D6": "地下委托 560 铜：D1 方案下加入后仍满足 L2_primary 则按一次性剧情奖励加入。",
    "D7": "银行与投资：只有模型显示正常年份平均有 ≥5% 的活跃玩家低于恢复线（缺钱）时才考虑进首版；否则留作候选。投资热情景另报是否破 L1/L2。",
    "D8": "恢复基金：正常情景一年内都没用光则维持 96 万；否则建议规模取最大年用量的 1.5 倍，并沿用“用光即不发、主线靠不可交易重试援助”。",
}


def family_import(d1: Ext):
    out = []
    for cap in (0, 500, 1000, 2000, 4000, LOCAL_BALANCE_CAP):
        out.append(replace(d1, name=f"launch_base·带入≤{cap}", family="import", base="launch_base", import_cap=cap))
    return out


def family_coverage(d1: Ext):
    out = []
    for base in ("launch_base", "supply_half_90_repair", "supply_half_90_no_repair", "bed_half_10"):
        for inc in (0.0, 0.25, 0.5, 1.0):
            out.append(replace(d1, name=f"{base}·玩家篮子{inc}", family="coverage", base=base, need_increment=inc))
    return out


def family_scale(d1: Ext):
    out = []
    for base in NORMAL_BASES:
        for k in (1.0, 2.0, 4.0, 8.0, 16.0):
            out.append(replace(d1, name=f"{base}·付100%·标尺×{k:g}", family="scale", base=base, scale=k, share=1.0))
    return out


def family_lines(d1: Ext):
    normal = [replace(d1, name=f"{b}·正常", family="lines", base=b) for b in ("launch_base", "steady_fresh20", "dormant_return_200", "investment_heat")]
    controls = [
        Ext("反例·照单机发币", "lines", "launch_base", loop="mint", control=True),
        Ext("反例·每活跃玩家每天无源+30", "lines", "launch_base", unbacked_per_active=30, control=True),
        replace(d1, name="反例·新人立即领满（steady_fresh20_instant）", family="lines", base="steady_fresh20_instant", control=True),
        replace(d1, name="反例·开服全员立即领满（launch_2000_instant）", family="lines", base="launch_2000_instant", control=True),
    ]
    return normal + controls


def family_underground(d1: Ext):
    return [replace(d1, name=f"{b}·地下委托{'有' if u else '无'}", family="underground", base=b, underground=u)
            for b in NORMAL_BASES for u in (False, True)]


def family_bank(d1: Ext):
    return [replace(d1, name=f"{b}·银行投资", family="bank", base=b) for b in ("launch_base", "investment_heat")]


def run_family(exts, workers):
    jobs = [(e, s) for e in exts for s in SEEDS]
    with ProcessPoolExecutor(max_workers=workers) as pool:
        return list(pool.map(run_one, jobs))


def group(results):
    by = {}
    for r in results:
        by.setdefault(r["ext"]["name"], []).append(r)
    return by


def all_pass(runs, line):
    return all(r[line] for r in runs)


def summarize(runs):
    f = lambda k: [r[k] for r in runs if r[k] is not None]
    def rng(k, fmt="{:.2f}"):
        vals = f(k)
        return (fmt.format(min(vals)) + ("–" + fmt.format(max(vals)) if max(vals) != min(vals) else "")) if vals else "—"
    return {
        "峰值": rng("peak_index"), "30天变化": rng("max_30d_change", "{:.0%}"), "全年": rng("annual_change", "{:+.0%}"),
        "篮子最低": rng("fill_min", "{:.1%}"), "货币增长": rng("money_growth", "{:+.0%}"),
        "每日玩法付出": rng("loop_paid_share", "{:.0%}"), "玩家中位现金": rng("player_cash_median", "{:.0f}"),
        "低于恢复线": rng("below_floor_share", "{:.1%}"), "恢复基金最低": rng("recovery_fund_min", "{:.0f}"),
        "L1": sum(r["L1"] for r in runs), "L2": sum(r["L2_primary"] for r in runs), "L2严": sum(r["L2_strict"] for r in runs),
        "L3": sum(r["L3"] for r in runs), "n": len(runs),
    }


def table(results, cols=("峰值", "30天变化", "全年", "篮子最低", "货币增长", "每日玩法付出", "玩家中位现金", "低于恢复线", "L1", "L2", "L2严", "L3")):
    lines = ["| 情景 | " + " | ".join(cols) + " |", "|---|" + "---|" * len(cols)]
    for name, runs in group(results).items():
        s = summarize(runs)
        cells = [f"{s[c]}/{s['n']}" if c in ("L1", "L2", "L2严", "L3") else str(s[c]) for c in cols]
        lines.append(f"| {name} | " + " | ".join(cells) + " |")
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    report = ["# 共享服经济：用模拟定候选（V3 模型扩展）", "",
              "模型：Pro V3 按天整服模型（只读导入）＋本脚本的钩子。5 个种子 × 365 天。是设计模型，不是游戏实装，也不是“真实服务器不会通胀”的证明。", "",
              "## 事先定下的验收线与判定规则", ""]
    report += [f"- **{k}**：{v}" for k, v in LINES.items()] + [""] + [f"- **{k}**：{v}" for k, v in RULES.items()] + [""]
    report += ["每日玩法每个活跃日的铜（来自人类计时模拟，一般速度、全都做）：",
               f"第一章 {json.dumps({k: round(v, 1) for k, v in LOOP['chapter'].items()}, ensure_ascii=False)}，底料 {LOOP['chapter_stock']:.1f}；"
               f"之后 {json.dumps({k: round(v, 1) for k, v in LOOP['post'].items()}, ensure_ascii=False)}，底料 {LOOP['post_stock']:.1f}。", ""]
    all_results = []

    funding = run_family(family_funding(), args.workers)
    all_results += funding
    report += ["## D1 每日玩法的铜从哪来", ""] + table(funding) + [""]
    best = pick_funding(funding)
    if best:
        share, tax, paid = best
        chosen = Ext("D1", "chosen", "launch_base", loop="funded", share=share, tax=tax)
        report += [f"**D1 判定**：共享服里每日玩法付单机的 {share:.0%}，由城市预算付，城市按 {tax:.0%} 从 NPC 基础消费和开放服务消费收钱"
                   f"（两个正常年份、5 个种子都过 L1/L2/L3，平均实付 {paid:.0%}）。照单机全额发币会通胀（见表）。", ""]
    else:
        chosen = Ext("D1", "chosen", "launch_base", loop="funded", share=0.1, tax=0.2)
        report += ["**D1 判定**：没有组合同时过 L1/L2/L3 且实付 ≥95%；以下各族暂用付 10%、税 20% 继续比较。", ""]

    decisions = {"D1": report[-2]}

    res = run_family(family_import(chosen), args.workers); all_results += res
    passing_caps = [runs[0]["ext"]["import_cap"] for runs in group(res).values() if all_pass(runs, "L2_primary")]
    cap = max(passing_caps) if passing_caps else 0
    decisions["D2"] = f"**D2 判定**：本地财富带入上限 {cap} 铜（开服批里一半玩家带单机存档，余额中位 2000、最多 12000）。"
    report += ["## D2 本地财富带入", ""] + table(res) + ["", decisions["D2"], ""]

    res = run_family(family_coverage(chosen), args.workers); all_results += res
    g = group(res)
    ok_cov = []
    for inc in (0.0, 0.25, 0.5, 1.0):
        normal_ok = all_pass(g[f"launch_base·玩家篮子{inc}"], "L1")
        repaired_ok = all_pass(g[f"supply_half_90_repair·玩家篮子{inc}"], "L1")
        if normal_ok and repaired_ok:
            ok_cov.append(inc)
    cov = max(ok_cov) if ok_cov else None
    decisions["D3"] = (f"**D3 判定**：玩家每活跃日累积 {cov} 份保护篮子需求（正常年份与修复的供给减半都过 L1）。"
                       if cov is not None else "**D3 判定**：没有覆盖档在修复的冲击里过 L1；保护范围需先加储备或产能。")
    report += ["## D3 保护篮子覆盖", ""] + table(res) + ["", decisions["D3"], ""]

    # Sensitivity (reported, does not change D1): D1's grid again with players buying the D3
    # coverage, since their basket spending is part of what returns to NPC households.
    if cov is not None and cov != v3.Config().player_need_increment:
        res = run_family(family_funding(need_increment=cov, family="funding_at_coverage"), args.workers); all_results += res
        again = pick_funding(res)
        decisions["S1"] = (f"**S1 复核**：玩家每活跃日买 {cov:g} 份篮子时，按 D1 同一规则可付单机的 {again[0]:.0%}（税 {again[1]:.0%}，平均实付 {again[2]:.0%}）。"
                           if again else f"**S1 复核**：玩家每活跃日买 {cov:g} 份篮子时，没有组合通过 D1 的规则。")
        report += [f"## S1 复核：D1 在玩家篮子 {cov:g} 下", ""] + table(res) + ["", decisions["S1"], ""]

    res = run_family(family_scale(chosen), args.workers); all_results += res
    g = group(res)
    def scale_ok(k):
        runs = [r for b in NORMAL_BASES for r in g[f"{b}·付100%·标尺×{k:g}"]]
        return all(r["L1"] and r["L2_primary"] and r["L3"] for r in runs) and statistics.mean(r["loop_paid_share"] or 0 for r in runs) >= 0.95
    ks = [k for k in (1.0, 2.0, 4.0, 8.0, 16.0) if scale_ok(k)]
    k = min(ks) if ks else None
    if chosen.share >= 1.0:
        decisions["D4"] = "**D4 判定**：保留 24/12：不放大物价也能按单机全额付每日玩法。"
    elif k:
        decisions["D4"] = (f"**D4 判定**：24/12 下只能付单机的 {chosen.share:.0%}；若要按全额付，需要 NPC 价格与资金整体乘 {k:g}"
                           f"（税率同为 {chosen.tax:.0%}）。两条路并列给用户选：保留 24/12 并把共享服每日玩法的铜打折，或放大 NPC 物价。")
    else:
        decisions["D4"] = f"**D4 判定**：24/12 下只能付单机的 {chosen.share:.0%}；放大到 16 倍也付不起全额。保留 24/12，共享服每日玩法的铜按 D1 打折。"
    report += ["## D4 24/12 标尺", ""] + table(res) + ["", decisions["D4"], ""]

    res = run_family(family_lines(chosen), args.workers); all_results += res
    g = group(res)
    normal_runs = [r for runs in g.values() for r in runs if not r["ext"]["control"]]
    control_groups = {n: runs for n, runs in g.items() if runs[0]["ext"]["control"]}
    def discriminates(line):
        return all(r[line] for r in normal_runs) and all(not all_pass(runs, line) and not any(r[line] for r in runs) for runs in control_groups.values())
    if discriminates("L2_strict"):
        decisions["D5"] = "**D5 判定**：采用严格价格线 L2_strict（正常情景全过，反例全挂）。"
    elif discriminates("L2_primary"):
        decisions["D5"] = "**D5 判定**：采用主价格线 L2_primary（正常情景全过，反例全挂；严格线会误伤正常情景或放过反例）。"
    else:
        weak = [n for n, runs in control_groups.items() if any(r["L2_primary"] for r in runs)]
        failing = sorted({r["ext"]["name"] for r in normal_runs if not r["L2_primary"]})
        decisions["D5"] = f"**D5 判定**：主价格线区分力不够。放过的反例：{weak or '无'}；误伤的正常情景：{failing or '无'}。"
    report += ["## D5 验收线的区分力", ""] + table(res) + ["", decisions["D5"], ""]

    res = run_family(family_underground(chosen), args.workers); all_results += res
    g = group(res)
    ug_ok = all(all_pass(g[f"{b}·地下委托有"], "L2_primary") for b in NORMAL_BASES)
    decisions["D6"] = ("**D6 判定**：地下委托 560 铜按一次性剧情奖励加入（加入后仍过 L2）。" if ug_ok
                       else "**D6 判定**：加入 560 铜后破 L2，需减额或改成非铜奖励。")
    report += ["## D6 地下委托", ""] + table(res) + ["", decisions["D6"], ""]

    res = run_family(family_bank(chosen), args.workers); all_results += res
    g = group(res)
    below = statistics.mean(r["below_floor_share"] for r in g["launch_base·银行投资"])
    heat_ok = all_pass(g["investment_heat·银行投资"], "L1") and all_pass(g["investment_heat·银行投资"], "L2_primary")
    decisions["D7"] = (f"**D7 判定**：正常年份平均只有 {below:.1%} 的活跃玩家低于恢复线，玩家不缺现金，银行与投资留作候选、不进首版；"
                       f"投资热情景{'仍过' if heat_ok else '破'} L1/L2。" if below < 0.05 else
                       f"**D7 判定**：正常年份平均 {below:.1%} 的活跃玩家低于恢复线，缺钱明显，可考虑首版做只存不贷的票据柜台。")
    report += ["## D7 银行与投资", ""] + table(res) + ["", decisions["D7"], ""]

    # D8 from every normal run with the chosen funding.
    normal = [r for r in all_results if r["ext"]["loop"] == chosen.loop and r["ext"]["share"] == chosen.share
              and r["ext"]["tax"] == chosen.tax and r["ext"]["scale"] == 1.0 and not r["ext"]["control"] and r["ext"]["need_increment"] is None
              and r["ext"]["base"] in ("launch_base", "steady_fresh20", "dormant_return_200", "investment_heat")]
    used = [960000 - r["recovery_fund_min"] for r in normal]
    fund_ok = all(r["recovery_fund_min"] > 0 for r in normal)
    decisions["D8"] = (f"**D8 判定**：恢复基金维持 96 万：选定方案的正常情景一年最多用掉 {max(used):,.0f}，最低余额 {min(r['recovery_fund_min'] for r in normal):,.0f}。"
                       if fund_ok else f"**D8 判定**：恢复基金会用光，建议规模 {int(max(used) * 1.5):,}，用光即不发、主线靠不可交易重试援助。")
    report += ["## D8 恢复基金", "", decisions["D8"], ""]
    report += ["## 判定汇总", ""] + [decisions[k] for k in sorted(decisions)] + [""]
    (out / "decisions.json").write_text(json.dumps(decisions, ensure_ascii=False, indent=1))

    (out / "results.json").write_text(json.dumps(all_results, ensure_ascii=False, indent=1, default=list))
    with (out / "results.csv").open("w", newline="") as f:
        keys = ["name", "family", "seed", "peak_index", "max_30d_change", "annual_change", "fill_min", "fill_share_99", "recovery_days",
                "money_growth", "mint_cum", "loop_paid_share", "player_cash_median", "below_floor_share", "recovery_fund_min",
                "stabilizer_min_share", "L1", "L2_primary", "L2_strict", "L3"]
        w = csv.writer(f); w.writerow(keys)
        for r in all_results:
            w.writerow([r["ext"]["name"], r["ext"]["family"], r["seed"]] + [r[k] for k in keys[3:]])
    (out / "report.md").write_text("\n".join(report) + "\n")
    (out / "chosen.json").write_text(json.dumps(asdict(chosen), ensure_ascii=False, indent=1))
    print("\n".join(report))


if __name__ == "__main__":
    main()
