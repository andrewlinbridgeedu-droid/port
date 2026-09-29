#!/usr/bin/env python3
"""
Mistport server economy stress model v3
Standard library only.

Purpose:
- Reproduce the 2,000-resident server monetary/physical stress calculations.
- Separate current in-server residents from lifetime accounts.
- Track fresh-player entitlement creation, realized minting, server transfers,
  dormant archived balances, imports with full prepayment, basic-goods stock,
  player cash-constrained demand, durable bicycle/pump stock, and bank algebra.

This is a DESIGN MODEL, not game code and not evidence that the live game is balanced.

Currency:
- Internal unit: copper only.
- Display convention: 100 copper = 1 gold (display only).

Time:
- One economic day = one 24h server accounting boundary.
- Personal story progress is NOT gated by economic days. In this model,
  active days are only a pacing proxy for when first-time reward receipts
  are likely to be claimed.
- Player contract/gameplay milestones should remain event-driven in the game.

No third-party packages required.
"""

from __future__ import annotations
from dataclasses import dataclass, field, replace
from typing import Dict, List, Tuple, Optional
import csv
import json
import math
import random
import statistics
import os

# ---------------------------
# Exact currently reported reward totals used as model inputs
# ---------------------------

MAINLINE_REWARDS = (
    [30] * 5
    + [40] * 5
    + [50] * 5
    + [80] * 5
    + [100] * 5
    + [120] * 4
    + [300]
)
assert len(MAINLINE_REWARDS) == 30
assert sum(MAINLINE_REWARDS) == 2280

TOWER_REWARDS = [8 + 2 * ((f - 1) // 10) for f in range(1, 101)]
assert len(TOWER_REWARDS) == 100
assert sum(TOWER_REWARDS) == 1700

BOUNTY_REWARDS = [60, 60, 80, 80, 110, 120, 100, 160, 150, 140]
assert sum(BOUNTY_REWARDS) == 1060

INITIAL_REWARD = 180
FULL_FIRST_TIME_ENTITLEMENT = INITIAL_REWARD + sum(MAINLINE_REWARDS) + sum(TOWER_REWARDS) + sum(BOUNTY_REWARDS)
assert FULL_FIRST_TIME_ENTITLEMENT == 5220

# This fixed queue is a monetary pacing envelope, not a claim about exact unlock order.
# Mainline rewards are interleaved with tower/bounty slices so 5,040 post-entry copper
# does not arrive all at once.
def build_reward_queue() -> List[int]:
    queue: List[int] = []
    tower_idx = 0
    bounty_idx = 0
    tower_release = {5: 10, 10: 20, 13: 20, 16: 20, 20: 30}
    bounty_release = {5: 1, 10: 2, 13: 2, 16: 2, 20: 1, 26: 2}
    for q, reward in enumerate(MAINLINE_REWARDS, start=1):
        queue.append(reward)
        if q in tower_release:
            n = tower_release[q]
            queue.extend(TOWER_REWARDS[tower_idx:tower_idx+n])
            tower_idx += n
        if q in bounty_release:
            n = bounty_release[q]
            queue.extend(BOUNTY_REWARDS[bounty_idx:bounty_idx+n])
            bounty_idx += n
    assert tower_idx == 100
    assert bounty_idx == 10
    assert sum(queue) == 5040
    return queue

REWARD_QUEUE = build_reward_queue()

def build_q_by_cursor() -> List[int]:
    out = [0]
    tower_release = {5: 10, 10: 20, 13: 20, 16: 20, 20: 30}
    bounty_release = {5: 1, 10: 2, 13: 2, 16: 2, 20: 1, 26: 2}
    for q, reward in enumerate(MAINLINE_REWARDS, start=1):
        out.append(q)  # after claiming this mainline reward
        for _ in range(tower_release.get(q, 0)):
            out.append(q)
        for _ in range(bounty_release.get(q, 0)):
            out.append(q)
    assert len(out) == len(REWARD_QUEUE) + 1
    return out

Q_BY_CURSOR = build_q_by_cursor()


# ---------------------------
# Config
# ---------------------------

@dataclass(frozen=True)
class Config:
    days: int = 365
    resident_cap: int = 2000
    replacements_per_day: int = 20

    # Activity: 2000 residents * 0.35 ~= 700 DAU before RNG noise.
    activity_rate: float = 0.35
    avg_hours_per_dau: float = 1.8
    peak_ccu_multiplier: float = 2.45

    # Stable economic-role distribution. 60% do not participate in shared economy.
    role_none: float = 0.60
    role_worker: float = 0.25
    role_investor: float = 0.12
    role_operator: float = 0.02
    role_banker: float = 0.01

    # Churn composition among replacements.
    fresh_share: float = 0.50
    departing_transfer_share: float = 0.50  # remainder becomes dormant archive
    transfer_in_cash_median: int = 900
    transfer_in_cash_sigma: float = 0.75
    transfer_in_cash_cap: int = 8000

    # Story reward pacing proxy: reward milestones claimed per active day.
    reward_milestones_per_active_day: int = 2
    instant_full_fresh_entitlement: bool = False
    instant_initial_entitlement: bool = False

    # Shared J0 redesign candidate: deficit-gated fiscal transfer, NOT mint.
    # It is NOT a 12-use guarantee. A player can requalify if legitimate spending
    # reduces cash below the progress-sensitive recovery floor.
    shared_j0_payment: int = 40
    recovery_floor_pre_q17: int = 180
    recovery_floor_q17: int = 380
    recovery_floor_q20: int = 460
    recovery_floor_q23: int = 600
    recovery_floor_post_q30: int = 400

    # Basic protected basket, candidate only:
    # non-fuel goods 8 + household fuel 1 + bed/service 3 = 12 copper.
    basket_price: int = 12
    nonfuel_price: int = 8
    household_fuel_price_per_kg: int = 2
    bed_price: int = 3

    # Physical base demand.
    npc_population: int = 10000
    npc_consumption_equivalents: int = 8000

    # Player need accrues only when active; 0.25 means one protected basket every
    # four active economic days in this model. This is NOT an offline food tax.
    player_need_increment: float = 0.25

    # Cash-driven discretionary services (not protected basket).
    # Each active player allocates 0.2% of cash above protected reserve, max 30/day.
    discretionary_rate: float = 0.005
    discretionary_daily_cap: int = 30
    discretionary_buffer: int = 600
    open_service_base_price: float = 10.0
    open_service_capacity: float = 500.0

    # Non-fuel goods production and reserve.
    nonfuel_capacity_per_day: int = 12000
    nonfuel_reserve_target: int = 140000
    nonfuel_reserve_initial: int = 140000
    nonfuel_domestic_unit_cost: int = 7  # sell 8
    nonfuel_import_unit_cost: int = 10   # sell protected portion at 8
    nonfuel_import_cap_per_day: int = 1500
    nonfuel_import_external_inventory: int = 21000
    nonfuel_import_lead_days: int = 1

    # Household fuel is separate from industrial/security strategic fuel.
    # No double counting with nonfuel reserve or industrial fuel reserve.
    household_fuel_capacity_kg_per_day: int = 6000
    household_fuel_reserve_target_kg: int = 70000
    household_fuel_reserve_initial_kg: int = 70000
    household_fuel_per_basket_kg: float = 0.5
    household_fuel_domestic_cost_per_kg: int = 2  # 0.5kg costs 1 copper per basket
    household_fuel_import_cost_per_kg: int = 4
    household_fuel_import_cap_kg_per_day: int = 1000
    household_fuel_import_external_inventory_kg: int = 14000
    household_fuel_import_lead_days: int = 1

    bed_capacity_per_day: int = 10800

    # Separate industrial/security fuel stock; not used for household basket.
    industrial_fuel_capacity_kg_per_day: int = 15000
    industrial_fuel_reserve_initial_kg: int = 180000
    industrial_fuel_safety_floor_kg: int = 30000
    industrial_fuel_normal_demand_kg_per_day: int = 12000

    # Day-0 money accounts, total exactly 7,000,000 copper before player mint.
    npc_household_cash: int = 1_500_000
    other_producer_cash: int = 500_000
    bike_industry_cash: int = 300_000
    pump_industry_cash: int = 200_000
    general_business_cash: int = 660_000
    transport_customer_cash: int = 600_000
    industrial_customer_cash: int = 400_000
    npc_financial_cash: int = 500_000
    treasury_general_cash: int = 800_000
    stabilizer_cash: int = 540_000
    recovery_fund_cash: int = 960_000
    system_emergency_cash: int = 40_000

    # Internal operating revenue that replenishes durable-goods buyers;
    # transferred from general business, never minted.
    transport_service_revenue_per_day: int = 1200
    industrial_service_revenue_per_day: int = 1000

    # Durable stock model; customer budgets do not reset.
    industry_cycle_days: int = 30
    bike_sale_price: int = 160
    bike_variable_cost: int = 110
    bike_sector_setup_cost_once: int = 460
    bike_cycle_maintenance: int = 200
    bike_cycle_capacity: int = 240
    bike_life_days: int = 540

    pump_sale_price: int = 1600
    pump_variable_cost: int = 1060
    pump_sector_setup_cost_once: int = 760
    pump_cycle_maintenance: int = 120
    pump_cycle_capacity: int = 20
    pump_life_days: int = 720

    # Player-operated project capacity in normal server, not total world market.
    player_bike_batches_per_cycle: int = 14  # 10 bikes/batch
    player_pump_batches_per_cycle: int = 6   # 2 pumps/batch
    bike_project_cost_10: int = 1560
    pump_project_cost_2: int = 2880

    # Optional finite exports after day 180.
    exports_enabled: bool = False
    bike_export_cycle_cap: int = 30
    pump_export_cycle_cap: int = 2
    foreign_bike_budget_initial: int = 120_000
    foreign_pump_budget_initial: int = 64_000

    # Supply shock ranges inclusive. Set start > end for none.
    nonfuel_shock_start: int = 999999
    nonfuel_shock_end: int = -1
    nonfuel_shock_factor: float = 1.0
    household_fuel_shock_factor: float = 1.0
    bed_shock_factor: float = 1.0

    # Optional physical expansion during shock.
    expansion_day: int = 999999
    expansion_nonfuel_capacity: int = 0
    expansion_cost: int = 180_000

    # Industrial fuel war shock
    fuel_war_start: int = 999999
    fuel_war_end: int = -1
    fuel_war_capacity_factor: float = 1.0
    fuel_war_demand_kg_per_day: int = 15000
    industrial_fuel_import_cap_kg_per_day: int = 3000
    industrial_fuel_import_days: int = 14

    # Optional day when dormant balances are forced back into active server.
    dormant_return_day: int = 999999
    dormant_return_accounts: int = 0

    # Stress: all active players submit 100 copper of investment demand each cycle.
    all_active_investment_heat: bool = False

    def validate(self) -> None:
        role_sum = self.role_none + self.role_worker + self.role_investor + self.role_operator + self.role_banker
        assert abs(role_sum - 1.0) < 1e-9
        initial = (
            self.npc_household_cash
            + self.other_producer_cash
            + self.bike_industry_cash
            + self.pump_industry_cash
            + self.general_business_cash
            + self.transport_customer_cash
            + self.industrial_customer_cash
            + self.npc_financial_cash
            + self.treasury_general_cash
            + self.stabilizer_cash
            + self.recovery_fund_cash
            + self.system_emergency_cash
        )
        assert initial == 7_000_000, initial
        assert self.nonfuel_price + self.household_fuel_price_per_kg * self.household_fuel_per_basket_kg + self.bed_price == self.basket_price

# ---------------------------
# Data types
# ---------------------------

@dataclass
class Player:
    pid: int
    cash: int = 0
    reward_cursor: int = 0
    q_completed: int = 0
    need: float = 0.0
    role: str = "none"
    origin: str = "fresh"
    full_entitlement_created: bool = False
    entitlement_completed: bool = False

@dataclass
class PendingImport:
    delivery_day: int
    qty: int
    kind: str  # "nonfuel" or "household_fuel"
    prepaid_cash: int

@dataclass
class PendingIndustryOrder:
    delivery_day: int
    kind: str  # bike or pump
    local_qty: float
    export_qty: float
    local_escrow: int
    export_escrow: int
    production_cost: int

@dataclass
class World:
    cfg: Config
    rng: random.Random
    next_pid: int = 1
    residents: Dict[int, Player] = field(default_factory=dict)
    dormant: Dict[int, Player] = field(default_factory=dict)

    npc_household_cash: int = 0
    other_producer_cash: int = 0
    bike_industry_cash: int = 0
    pump_industry_cash: int = 0
    general_business_cash: int = 0
    transport_customer_cash: int = 0
    industrial_customer_cash: int = 0
    npc_financial_cash: int = 0
    treasury_general_cash: int = 0
    stabilizer_cash: int = 0
    recovery_fund_cash: int = 0
    system_emergency_cash: int = 0
    order_escrow_cash: int = 0

    nonfuel_reserve: float = 0.0
    imported_nonfuel_stock: float = 0.0
    household_fuel_reserve_kg: float = 0.0
    imported_household_fuel_stock_kg: float = 0.0
    industrial_fuel_reserve_kg: float = 0.0

    pending_imports: List[PendingImport] = field(default_factory=list)
    pending_industry_orders: List[PendingIndustryOrder] = field(default_factory=list)

    bike_installed: float = 0.0
    pump_installed: float = 0.0
    bike_setup_done: bool = False
    pump_setup_done: bool = False

    foreign_bike_budget: int = 0
    foreign_pump_budget: int = 0
    foreign_nonfuel_inventory: int = 0
    foreign_household_fuel_inventory_kg: int = 0

    cumulative_mint: int = 0
    cumulative_entitlement_created: int = 0
    cumulative_transfer_in: int = 0
    cumulative_transfer_out: int = 0
    cumulative_import_outflow: int = 0
    cumulative_export_inflow: int = 0
    cumulative_retirement: int = 0
    cumulative_j0_paid: int = 0

    total_initial_system_money: int = 7_000_000

    expansion_paid: bool = False

    def __post_init__(self) -> None:
        c = self.cfg
        self.npc_household_cash = c.npc_household_cash
        self.other_producer_cash = c.other_producer_cash
        self.bike_industry_cash = c.bike_industry_cash
        self.pump_industry_cash = c.pump_industry_cash
        self.general_business_cash = c.general_business_cash
        self.transport_customer_cash = c.transport_customer_cash
        self.industrial_customer_cash = c.industrial_customer_cash
        self.npc_financial_cash = c.npc_financial_cash
        self.treasury_general_cash = c.treasury_general_cash
        self.stabilizer_cash = c.stabilizer_cash
        self.recovery_fund_cash = c.recovery_fund_cash
        self.system_emergency_cash = c.system_emergency_cash

        self.nonfuel_reserve = float(c.nonfuel_reserve_initial)
        self.household_fuel_reserve_kg = float(c.household_fuel_reserve_initial_kg)
        self.industrial_fuel_reserve_kg = float(c.industrial_fuel_reserve_initial_kg)

        self.foreign_bike_budget = c.foreign_bike_budget_initial
        self.foreign_pump_budget = c.foreign_pump_budget_initial
        self.foreign_nonfuel_inventory = c.nonfuel_import_external_inventory
        self.foreign_household_fuel_inventory_kg = c.household_fuel_import_external_inventory_kg

    def make_role(self) -> str:
        r = self.rng.random()
        c = self.cfg
        edges = [
            (c.role_none, "none"),
            (c.role_none + c.role_worker, "worker"),
            (c.role_none + c.role_worker + c.role_investor, "investor"),
            (c.role_none + c.role_worker + c.role_investor + c.role_operator, "operator"),
            (1.0, "banker"),
        ]
        for edge, role in edges:
            if r < edge:
                return role
        return "none"

    def new_player(self, origin: str, cash: int = 0, mature: bool = False) -> Player:
        p = Player(
            pid=self.next_pid,
            cash=cash,
            reward_cursor=len(REWARD_QUEUE) if mature else 0,
            q_completed=30 if mature else 0,
            need=0.0,
            role=self.make_role(),
            origin=origin,
            full_entitlement_created=(origin == "fresh"),
            entitlement_completed=mature,
        )
        self.next_pid += 1
        return p

    def mint_to_player(self, p: Player, amount: int) -> None:
        assert amount >= 0
        p.cash += amount
        self.cumulative_mint += amount

    def create_fresh_entitlement(self, p: Player, instant_full: bool = False) -> int:
        if not p.full_entitlement_created:
            p.full_entitlement_created = True
        self.cumulative_entitlement_created += FULL_FIRST_TIME_ENTITLEMENT
        if instant_full:
            self.mint_to_player(p, FULL_FIRST_TIME_ENTITLEMENT)
            p.reward_cursor = len(REWARD_QUEUE)
            p.q_completed = 30
            p.entitlement_completed = True
            return FULL_FIRST_TIME_ENTITLEMENT
        else:
            self.mint_to_player(p, INITIAL_REWARD)
            return INITIAL_REWARD

    def active_server_money(self) -> int:
        resident_cash = sum(p.cash for p in self.residents.values())
        return int(round(
            resident_cash
            + self.npc_household_cash
            + self.other_producer_cash
            + self.bike_industry_cash
            + self.pump_industry_cash
            + self.general_business_cash
            + self.transport_customer_cash
            + self.industrial_customer_cash
            + self.npc_financial_cash
            + self.treasury_general_cash
            + self.stabilizer_cash
            + self.recovery_fund_cash
            + self.system_emergency_cash
            + self.order_escrow_cash
        ))

    def archived_money(self) -> int:
        return sum(p.cash for p in self.dormant.values())

# ---------------------------
# Player / reward logic
# ---------------------------

def estimate_q_completed_from_cursor(cursor: int) -> int:
    return Q_BY_CURSOR[min(max(0, cursor), len(REWARD_QUEUE))]

def recovery_floor(cfg: Config, q: int) -> int:
    if q < 17:
        return cfg.recovery_floor_pre_q17
    if q < 20:
        return cfg.recovery_floor_q17
    if q < 23:
        return cfg.recovery_floor_q20
    if q < 30:
        return cfg.recovery_floor_q23
    return cfg.recovery_floor_post_q30

def claim_story_rewards(world: World, p: Player) -> int:
    if p.entitlement_completed:
        return 0
    c = world.cfg
    claimed = 0
    for _ in range(c.reward_milestones_per_active_day):
        if p.reward_cursor >= len(REWARD_QUEUE):
            p.entitlement_completed = True
            break
        amt = REWARD_QUEUE[p.reward_cursor]
        world.mint_to_player(p, amt)
        claimed += amt
        p.reward_cursor += 1
    p.q_completed = estimate_q_completed_from_cursor(p.reward_cursor)
    if p.reward_cursor >= len(REWARD_QUEUE):
        p.entitlement_completed = True
    return claimed

# ---------------------------
# Churn
# ---------------------------

def draw_transfer_cash(world: World) -> int:
    c = world.cfg
    mu = math.log(max(1, c.transfer_in_cash_median))
    x = int(round(world.rng.lognormvariate(mu, c.transfer_in_cash_sigma)))
    return max(0, min(c.transfer_in_cash_cap, x))

def replace_residents(world: World, day: int) -> Tuple[int, int, int, int, int]:
    c = world.cfg
    n = min(c.replacements_per_day, len(world.residents))
    if n <= 0:
        return (0, 0, 0, 0, 0)

    departing_ids = world.rng.sample(list(world.residents.keys()), n)
    transfer_out_cash = 0
    archived_out_cash = 0
    for pid in departing_ids:
        p = world.residents.pop(pid)
        if world.rng.random() < c.departing_transfer_share:
            transfer_out_cash += p.cash
            world.cumulative_transfer_out += p.cash
        else:
            archived_out_cash += p.cash
            world.dormant[p.pid] = p

    fresh_n = 0
    transfer_in_n = 0
    transfer_in_cash = 0
    for _ in range(n):
        if world.rng.random() < c.fresh_share:
            p = world.new_player("fresh", 0, mature=False)
            world.create_fresh_entitlement(p, instant_full=c.instant_full_fresh_entitlement)
            fresh_n += 1
        else:
            cash = draw_transfer_cash(world)
            p = world.new_player("transfer_in", cash, mature=True)
            world.cumulative_transfer_in += cash
            transfer_in_cash += cash
            transfer_in_n += 1
        world.residents[p.pid] = p

    return fresh_n, transfer_in_n, transfer_in_cash, transfer_out_cash, archived_out_cash

def force_dormant_return(world: World, count: int) -> Tuple[int, int]:
    """Bring archived players back by replacing lowest-cash current residents.
    This is a stress scenario. Their archived balances are preserved, not minted.
    """
    if count <= 0 or not world.dormant:
        return (0, 0)
    ids = list(world.dormant.keys())
    world.rng.shuffle(ids)
    ids = ids[:min(count, len(ids), len(world.residents))]
    current_ids = sorted(world.residents, key=lambda pid: world.residents[pid].cash)
    current_ids = current_ids[:len(ids)]
    reactivated_cash = 0
    displaced_to_archive = 0
    for old_id, current_id in zip(ids, current_ids):
        cur = world.residents.pop(current_id)
        world.dormant[cur.pid] = cur
        displaced_to_archive += cur.cash

        p = world.dormant.pop(old_id)
        reactivated_cash += p.cash
        world.residents[p.pid] = p
    return reactivated_cash, displaced_to_archive

# ---------------------------
# Imports and protected basket
# ---------------------------

def deliver_imports(world: World, day: int) -> Tuple[int, int]:
    nf = 0
    hf = 0
    keep: List[PendingImport] = []
    for order in world.pending_imports:
        if order.delivery_day <= day:
            if order.kind == "nonfuel":
                world.imported_nonfuel_stock += order.qty
                nf += order.qty
            else:
                world.imported_household_fuel_stock_kg += order.qty
                hf += order.qty
        else:
            keep.append(order)
    world.pending_imports = keep
    return nf, hf

def order_imports(world: World, day: int, protected_demand: int, nf_capacity: int, hf_capacity_kg: int) -> Tuple[int, int, int]:
    c = world.cfg
    ordered_nf = 0
    ordered_hf = 0
    prepay = 0

    nf_gap = max(0, protected_demand - nf_capacity)
    if nf_gap > 0 and world.foreign_nonfuel_inventory > 0:
        max_by_cash = world.stabilizer_cash // c.nonfuel_import_unit_cost
        ordered_nf = int(min(c.nonfuel_import_cap_per_day, nf_gap, world.foreign_nonfuel_inventory, max_by_cash))
        if ordered_nf > 0:
            cost = ordered_nf * c.nonfuel_import_unit_cost
            world.stabilizer_cash -= cost
            world.foreign_nonfuel_inventory -= ordered_nf
            world.cumulative_import_outflow += cost
            prepay += cost
            world.pending_imports.append(
                PendingImport(day + c.nonfuel_import_lead_days, ordered_nf, "nonfuel", cost)
            )

    fuel_demand_kg = int(math.ceil(protected_demand * c.household_fuel_per_basket_kg))
    hf_gap = max(0, fuel_demand_kg - hf_capacity_kg)
    if hf_gap > 0 and world.foreign_household_fuel_inventory_kg > 0:
        max_by_cash = world.stabilizer_cash // c.household_fuel_import_cost_per_kg
        ordered_hf = int(min(c.household_fuel_import_cap_kg_per_day, hf_gap, world.foreign_household_fuel_inventory_kg, max_by_cash))
        if ordered_hf > 0:
            cost = ordered_hf * c.household_fuel_import_cost_per_kg
            world.stabilizer_cash -= cost
            world.foreign_household_fuel_inventory_kg -= ordered_hf
            world.cumulative_import_outflow += cost
            prepay += cost
            world.pending_imports.append(
                PendingImport(day + c.household_fuel_import_lead_days, ordered_hf, "household_fuel", cost)
            )
    return ordered_nf, ordered_hf, prepay

def capacities_for_day(world: World, day: int) -> Tuple[int, int, int]:
    c = world.cfg
    nf = c.nonfuel_capacity_per_day
    hf = c.household_fuel_capacity_kg_per_day
    bed = c.bed_capacity_per_day
    if c.nonfuel_shock_start <= day <= c.nonfuel_shock_end:
        nf = int(math.floor(nf * c.nonfuel_shock_factor))
        hf = int(math.floor(hf * c.household_fuel_shock_factor))
        bed = int(math.floor(bed * c.bed_shock_factor))
    if world.expansion_paid:
        nf += c.expansion_nonfuel_capacity
    return nf, hf, bed

def maybe_pay_expansion(world: World, day: int) -> int:
    c = world.cfg
    if (not world.expansion_paid) and day >= c.expansion_day and c.expansion_nonfuel_capacity > 0:
        if world.stabilizer_cash >= c.expansion_cost:
            world.stabilizer_cash -= c.expansion_cost
            world.other_producer_cash += c.expansion_cost
            world.expansion_paid = True
            return c.expansion_cost
    return 0

def allocate_player_baskets(world: World, buyers: List[int], player_fill: int) -> Tuple[int, int]:
    """Fulfill a random fair subset of player buyers. Returns (fulfilled, cash_paid)."""
    if player_fill <= 0 or not buyers:
        return 0, 0
    world.rng.shuffle(buyers)
    chosen = buyers[:min(player_fill, len(buyers))]
    paid = 0
    for pid in chosen:
        p = world.residents[pid]
        if p.cash >= world.cfg.basket_price and p.need >= 1.0:
            p.cash -= world.cfg.basket_price
            p.need -= 1.0
            paid += world.cfg.basket_price
    return len(chosen), paid

def process_protected_basket(
    world: World,
    day: int,
    active_ids: List[int],
    nf_capacity: int,
    hf_capacity_kg: int,
    bed_capacity: int,
) -> Dict[str, float]:
    c = world.cfg

    # Player need is activity-linked, not fixed purchase probability.
    for pid in active_ids:
        p = world.residents[pid]
        p.need = min(3.0, p.need + c.player_need_increment)

    player_buyers: List[int] = []
    player_afford_unmet = 0
    for pid in active_ids:
        p = world.residents[pid]
        if p.need >= 1.0:
            if p.cash >= c.basket_price:
                player_buyers.append(pid)
            else:
                player_afford_unmet += 1

    # NPC demand is also cash-constrained.
    npc_affordable = min(c.npc_consumption_equivalents, world.npc_household_cash // c.basket_price)
    npc_afford_unmet = c.npc_consumption_equivalents - npc_affordable
    total_demand = npc_affordable + len(player_buyers)

    # Current-day physical availability.
    nf_available = nf_capacity + world.imported_nonfuel_stock + world.nonfuel_reserve
    hf_available_baskets = (
        hf_capacity_kg + world.imported_household_fuel_stock_kg + world.household_fuel_reserve_kg
    ) / c.household_fuel_per_basket_kg

    physical_capacity = int(math.floor(min(nf_available, hf_available_baskets, bed_capacity)))
    fulfilled = min(total_demand, physical_capacity)

    # Fair proportional split between NPC and players.
    if total_demand > 0:
        player_fill = min(len(player_buyers), int(round(fulfilled * len(player_buyers) / total_demand)))
    else:
        player_fill = 0
    npc_fill = min(npc_affordable, fulfilled - player_fill)
    # Fill any rounding remainder.
    remainder = fulfilled - (player_fill + npc_fill)
    if remainder > 0:
        extra_p = min(remainder, len(player_buyers) - player_fill)
        player_fill += extra_p
        remainder -= extra_p
    if remainder > 0:
        npc_fill += min(remainder, npc_affordable - npc_fill)

    player_fulfilled, player_paid = allocate_player_baskets(world, player_buyers, player_fill)
    player_fill = player_fulfilled

    npc_payment = npc_fill * c.basket_price
    assert npc_payment <= world.npc_household_cash
    world.npc_household_cash -= npc_payment

    actual_fulfilled = npc_fill + player_fill
    total_payment = npc_payment + player_paid
    assert total_payment == actual_fulfilled * c.basket_price

    # Source nonfuel: direct domestic production -> imported stock -> treasury reserve.
    nf_need = actual_fulfilled
    nf_direct = min(nf_capacity, nf_need)
    nf_remaining = nf_need - nf_direct
    nf_import_used = min(world.imported_nonfuel_stock, nf_remaining)
    world.imported_nonfuel_stock -= nf_import_used
    nf_remaining -= nf_import_used
    nf_reserve_used = min(world.nonfuel_reserve, nf_remaining)
    world.nonfuel_reserve -= nf_reserve_used
    nf_remaining -= nf_reserve_used
    assert nf_remaining <= 1e-9

    # Source household fuel.
    hf_need = actual_fulfilled * c.household_fuel_per_basket_kg
    hf_direct = min(float(hf_capacity_kg), hf_need)
    hf_remaining = hf_need - hf_direct
    hf_import_used = min(world.imported_household_fuel_stock_kg, hf_remaining)
    world.imported_household_fuel_stock_kg -= hf_import_used
    hf_remaining -= hf_import_used
    hf_reserve_used = min(world.household_fuel_reserve_kg, hf_remaining)
    world.household_fuel_reserve_kg -= hf_reserve_used
    hf_remaining -= hf_reserve_used
    assert hf_remaining <= 1e-6

    # Route buyer payments:
    # Domestic direct portions pay producers. Imported/reserve portions are owned by stabilizer.
    domestic_nf_revenue = int(round(nf_direct * c.nonfuel_price))
    stabilizer_nf_revenue = int(round((nf_import_used + nf_reserve_used) * c.nonfuel_price))
    domestic_hf_revenue = int(round(hf_direct * c.household_fuel_price_per_kg))
    stabilizer_hf_revenue = int(round((hf_import_used + hf_reserve_used) * c.household_fuel_price_per_kg))
    bed_revenue = actual_fulfilled * c.bed_price

    routed = domestic_nf_revenue + stabilizer_nf_revenue + domestic_hf_revenue + stabilizer_hf_revenue + bed_revenue
    assert routed == total_payment, (routed, total_payment, actual_fulfilled)

    world.other_producer_cash += domestic_nf_revenue + domestic_hf_revenue + bed_revenue
    world.stabilizer_cash += stabilizer_nf_revenue + stabilizer_hf_revenue

    # Producers pay costs and distribute resulting margin to NPC households.
    # With integer model: nonfuel cost 7, household fuel cost 1, bed cost 2.
    domestic_cost = int(round(
        nf_direct * c.nonfuel_domestic_unit_cost
        + hf_direct * c.household_fuel_domestic_cost_per_kg
        + actual_fulfilled * 2
    ))
    producer_received = domestic_nf_revenue + domestic_hf_revenue + bed_revenue
    assert producer_received >= domestic_cost
    producer_margin = producer_received - domestic_cost
    # Costs + margin ultimately go to NPC households as wages/input income + owner income.
    world.other_producer_cash -= (domestic_cost + producer_margin)
    world.npc_household_cash += domestic_cost + producer_margin

    # After current consumption, unused domestic capacity can rebuild treasury-owned reserves,
    # but only if stabilizer has cash. Full purchase price is paid; no free inventory.
    nf_surplus_capacity = max(0, nf_capacity - int(math.ceil(nf_direct)))
    nf_rebuild_need = max(0, int(math.floor(c.nonfuel_reserve_target - world.nonfuel_reserve)))
    nf_rebuild = min(nf_surplus_capacity, nf_rebuild_need, world.stabilizer_cash // c.nonfuel_price)
    if nf_rebuild > 0:
        pay = nf_rebuild * c.nonfuel_price
        world.stabilizer_cash -= pay
        world.other_producer_cash += pay
        # producer pays cost+margin to households, same closure
        cost = nf_rebuild * c.nonfuel_domestic_unit_cost
        margin = pay - cost
        world.other_producer_cash -= (cost + margin)
        world.npc_household_cash += cost + margin
        world.nonfuel_reserve += nf_rebuild

    hf_surplus_capacity = max(0.0, hf_capacity_kg - hf_direct)
    hf_rebuild_need = max(0.0, c.household_fuel_reserve_target_kg - world.household_fuel_reserve_kg)
    hf_rebuild = min(hf_surplus_capacity, hf_rebuild_need, float(world.stabilizer_cash // c.household_fuel_price_per_kg))
    hf_rebuild = float(math.floor(hf_rebuild))
    if hf_rebuild > 0:
        pay = int(hf_rebuild * c.household_fuel_price_per_kg)
        world.stabilizer_cash -= pay
        world.other_producer_cash += pay
        cost = int(hf_rebuild * c.household_fuel_domestic_cost_per_kg)
        margin = pay - cost
        world.other_producer_cash -= (cost + margin)
        world.npc_household_cash += cost + margin
        world.household_fuel_reserve_kg += hf_rebuild

    total_legal_demand = c.npc_consumption_equivalents + len(player_buyers) + player_afford_unmet
    total_unmet = (
        (c.npc_consumption_equivalents - npc_fill)
        + (len(player_buyers) - player_fill)
        + player_afford_unmet
    )
    fulfillment = actual_fulfilled / total_legal_demand if total_legal_demand else 1.0

    return {
        "npc_demand": c.npc_consumption_equivalents,
        "npc_afford_unmet": npc_afford_unmet,
        "player_cash_demand": len(player_buyers),
        "player_afford_unmet": player_afford_unmet,
        "protected_demand_total": total_legal_demand,
        "protected_fulfilled": actual_fulfilled,
        "protected_unmet": total_unmet,
        "protected_fulfillment_rate": fulfillment,
        "player_fulfilled": player_fill,
        "npc_fulfilled": npc_fill,
        "nonfuel_direct": nf_direct,
        "nonfuel_import_used": nf_import_used,
        "nonfuel_reserve_used": nf_reserve_used,
        "household_fuel_direct_kg": hf_direct,
        "household_fuel_import_used_kg": hf_import_used,
        "household_fuel_reserve_used_kg": hf_reserve_used,
        "producer_margin": producer_margin,
        "total_basket_payment": total_payment,
    }

# ---------------------------
# Discretionary service market
# ---------------------------

def process_open_services(world: World, active_ids: List[int]) -> Dict[str, float]:
    c = world.cfg
    budgets: List[Tuple[int, int]] = []
    nominal = 0
    for pid in active_ids:
        p = world.residents[pid]
        excess = max(0, p.cash - c.discretionary_buffer)
        b = min(c.discretionary_daily_cap, int(math.floor(excess * c.discretionary_rate)))
        if b > 0:
            budgets.append((pid, b))
            nominal += b

    if nominal <= 0:
        price = c.open_service_base_price
        spent = 0
        qty = 0.0
    else:
        price = max(c.open_service_base_price, nominal / c.open_service_capacity)
        # At this clearing rule all nominated budgets can be spent only up to physical capacity.
        max_spend = int(math.floor(price * c.open_service_capacity))
        spent = min(nominal, max_spend)
        # proportional spending
        remaining = spent
        for i, (pid, b) in enumerate(budgets):
            p = world.residents[pid]
            if i == len(budgets) - 1:
                s = min(p.cash, remaining)
            else:
                s = min(p.cash, int(math.floor(spent * b / nominal)))
            p.cash -= s
            world.general_business_cash += s
            remaining -= s
        # if rounding leaves positive remainder, do a second pass
        if remaining > 0:
            for pid, b in budgets:
                if remaining <= 0:
                    break
                p = world.residents[pid]
                s = min(p.cash, remaining, b)
                p.cash -= s
                world.general_business_cash += s
                remaining -= s
        spent -= remaining
        qty = spent / price if price > 0 else 0.0

    return {
        "open_service_nominal_demand": nominal,
        "open_service_price": price,
        "open_service_price_index": price / c.open_service_base_price,
        "open_service_spent": spent,
        "open_service_qty": qty,
    }

# ---------------------------
# J0 fiscal recovery
# ---------------------------

def process_shared_j0(world: World, active_ids: List[int]) -> Tuple[int, int]:
    """Deficit-gated fiscal payment. Not a mint, not a fixed 12-use entitlement."""
    c = world.cfg
    tasks = 0
    paid = 0
    for pid in active_ids:
        p = world.residents[pid]
        floor = recovery_floor(c, p.q_completed)
        if p.cash < floor and world.recovery_fund_cash >= c.shared_j0_payment:
            world.recovery_fund_cash -= c.shared_j0_payment
            p.cash += c.shared_j0_payment
            world.cumulative_j0_paid += c.shared_j0_payment
            tasks += 1
            paid += c.shared_j0_payment
    return tasks, paid

# ---------------------------
# Durable industry stock-flow model
# ---------------------------

def bike_target(day: int) -> float:
    if day <= 180:
        return 600.0 + 1800.0 * day / 180.0
    return 2400.0 + 600.0 * (day - 180) / 185.0

def pump_target(day: int) -> float:
    if day <= 180:
        return 10.0 + 70.0 * day / 180.0
    return 80.0 + 40.0 * (day - 180) / 185.0

def deliver_industry_orders(world: World, day: int) -> Dict[str, float]:
    bike_delivered = 0.0
    pump_delivered = 0.0
    export_inflow = 0
    keep: List[PendingIndustryOrder] = []
    for o in world.pending_industry_orders:
        if o.delivery_day > day:
            keep.append(o)
            continue
        if o.kind == "bike":
            world.bike_industry_cash += o.local_escrow + o.export_escrow
            world.bike_installed += o.local_qty
            bike_delivered += o.local_qty
        else:
            world.pump_industry_cash += o.local_escrow + o.export_escrow
            world.pump_installed += o.local_qty
            pump_delivered += o.local_qty
        # escrow was already included in active money; local escrow moves internally.
        # export escrow was brought in from foreign sector at order time and also sits in escrow.
        world.order_escrow_cash -= (o.local_escrow + o.export_escrow)
    world.pending_industry_orders = keep
    return {
        "bike_delivered": bike_delivered,
        "pump_delivered": pump_delivered,
        "export_inflow_delivery": export_inflow,
    }

def daily_durable_depreciation(world: World) -> Tuple[float, float]:
    c = world.cfg
    bike_retired = world.bike_installed / c.bike_life_days
    pump_retired = world.pump_installed / c.pump_life_days
    world.bike_installed -= bike_retired
    world.pump_installed -= pump_retired
    return bike_retired, pump_retired

def pay_customer_operating_revenue(world: World) -> Tuple[int, int]:
    c = world.cfg
    t = min(world.general_business_cash, c.transport_service_revenue_per_day)
    world.general_business_cash -= t
    world.transport_customer_cash += t
    i = min(world.general_business_cash, c.industrial_service_revenue_per_day)
    world.general_business_cash -= i
    world.industrial_customer_cash += i
    return t, i

def create_industry_cycle(world: World, day: int, active_ids: List[int]) -> Dict[str, float]:
    c = world.cfg
    result = {
        "bike_local_order_qty": 0.0,
        "bike_export_order_qty": 0.0,
        "pump_local_order_qty": 0.0,
        "pump_export_order_qty": 0.0,
        "bike_customer_spend": 0,
        "pump_customer_spend": 0,
        "bike_project_cap_need": 0,
        "pump_project_cap_need": 0,
        "investor_demand": 0,
        "investment_accepted": 0,
        "investment_refund": 0,
        "investment_accept_rate": 1.0,
    }
    if day % c.industry_cycle_days != 0:
        return result

    # Pending local quantities already ordered but not yet delivered.
    pending_bike_local = sum(o.local_qty for o in world.pending_industry_orders if o.kind == "bike")
    pending_pump_local = sum(o.local_qty for o in world.pending_industry_orders if o.kind == "pump")

    bike_gap = max(0.0, bike_target(day) - world.bike_installed - pending_bike_local)
    pump_gap = max(0.0, pump_target(day) - world.pump_installed - pending_pump_local)

    bike_qty = min(float(c.bike_cycle_capacity), math.floor(bike_gap))
    pump_qty = min(float(c.pump_cycle_capacity), math.floor(pump_gap))

    # Local customer budgets are finite and do not refresh except from internal service revenue.
    bike_qty = min(bike_qty, world.transport_customer_cash // c.bike_sale_price)
    pump_qty = min(pump_qty, world.industrial_customer_cash // c.pump_sale_price)

    # Sector must also finance production from its own cash.
    bike_setup = 0 if world.bike_setup_done else c.bike_sector_setup_cost_once
    if bike_qty > 0:
        max_by_sector_cash = max(0, (world.bike_industry_cash - bike_setup - c.bike_cycle_maintenance) // c.bike_variable_cost)
        bike_qty = min(bike_qty, max_by_sector_cash)

    pump_setup = 0 if world.pump_setup_done else c.pump_sector_setup_cost_once
    if pump_qty > 0:
        max_by_sector_cash = max(0, (world.pump_industry_cash - pump_setup - c.pump_cycle_maintenance) // c.pump_variable_cost)
        pump_qty = min(pump_qty, max_by_sector_cash)

    bike_qty = float(max(0, int(bike_qty)))
    pump_qty = float(max(0, int(pump_qty)))

    # Optional finite export demand; external cash enters server only when order is placed.
    bike_export_qty = 0.0
    pump_export_qty = 0.0
    if c.exports_enabled and day > 180:
        bike_export_qty = float(min(
            c.bike_export_cycle_cap,
            world.foreign_bike_budget // c.bike_sale_price,
            max(0, c.bike_cycle_capacity - int(bike_qty)),
        ))
        pump_export_qty = float(min(
            c.pump_export_cycle_cap,
            world.foreign_pump_budget // c.pump_sale_price,
            max(0, c.pump_cycle_capacity - int(pump_qty)),
        ))

    # Fund production, reserve local customer money into escrow, and prepay export orders.
    if bike_qty + bike_export_qty > 0:
        q_total = int(bike_qty + bike_export_qty)
        prod_cost = bike_setup + c.bike_cycle_maintenance + c.bike_variable_cost * q_total
        if prod_cost <= world.bike_industry_cash:
            world.bike_industry_cash -= prod_cost
            world.other_producer_cash += prod_cost
            if not world.bike_setup_done:
                world.bike_setup_done = True
            local_escrow = int(bike_qty) * c.bike_sale_price
            assert local_escrow <= world.transport_customer_cash
            world.transport_customer_cash -= local_escrow
            export_escrow = int(bike_export_qty) * c.bike_sale_price
            world.foreign_bike_budget -= export_escrow
            world.cumulative_export_inflow += export_escrow
            world.order_escrow_cash += local_escrow + export_escrow
            world.pending_industry_orders.append(PendingIndustryOrder(
                day + 10, "bike", bike_qty, bike_export_qty,
                local_escrow, export_escrow, prod_cost
            ))
            result["bike_local_order_qty"] = bike_qty
            result["bike_export_order_qty"] = bike_export_qty
            result["bike_customer_spend"] = local_escrow
        else:
            bike_qty = 0.0
            bike_export_qty = 0.0

    if pump_qty + pump_export_qty > 0:
        q_total = int(pump_qty + pump_export_qty)
        prod_cost = pump_setup + c.pump_cycle_maintenance + c.pump_variable_cost * q_total
        if prod_cost <= world.pump_industry_cash:
            world.pump_industry_cash -= prod_cost
            world.other_producer_cash += prod_cost
            if not world.pump_setup_done:
                world.pump_setup_done = True
            local_escrow = int(pump_qty) * c.pump_sale_price
            assert local_escrow <= world.industrial_customer_cash
            world.industrial_customer_cash -= local_escrow
            export_escrow = int(pump_export_qty) * c.pump_sale_price
            world.foreign_pump_budget -= export_escrow
            world.cumulative_export_inflow += export_escrow
            world.order_escrow_cash += local_escrow + export_escrow
            world.pending_industry_orders.append(PendingIndustryOrder(
                day + 20, "pump", pump_qty, pump_export_qty,
                local_escrow, export_escrow, prod_cost
            ))
            result["pump_local_order_qty"] = pump_qty
            result["pump_export_order_qty"] = pump_export_qty
            result["pump_customer_spend"] = local_escrow
        else:
            pump_qty = 0.0
            pump_export_qty = 0.0

    # Diagnostic only: what would player subscription pressure look like?
    bike_player_batches = min(c.player_bike_batches_per_cycle, int(result["bike_local_order_qty"] // 10))
    pump_player_batches = min(c.player_pump_batches_per_cycle, int(result["pump_local_order_qty"] // 2))
    bike_cap_need = bike_player_batches * c.bike_project_cost_10
    pump_cap_need = pump_player_batches * c.pump_project_cost_2
    cap_need = bike_cap_need + pump_cap_need

    if c.all_active_investment_heat:
        investor_demand = 0
        for pid in active_ids:
            p = world.residents[pid]
            investor_demand += min(100, max(0, p.cash - 400))
    else:
        investor_demand = 0
        for pid in active_ids:
            p = world.residents[pid]
            if p.role in {"investor", "operator", "banker"}:
                investor_demand += min(100, max(0, p.cash - 400))

    accepted = min(investor_demand, cap_need)
    result["bike_project_cap_need"] = bike_cap_need
    result["pump_project_cap_need"] = pump_cap_need
    result["investor_demand"] = investor_demand
    result["investment_accepted"] = accepted
    result["investment_refund"] = max(0, investor_demand - accepted)
    result["investment_accept_rate"] = (accepted / investor_demand) if investor_demand > 0 else 1.0
    return result

# ---------------------------
# Industrial fuel war
# ---------------------------

def process_industrial_fuel(world: World, day: int) -> Dict[str, float]:
    c = world.cfg
    in_war = c.fuel_war_start <= day <= c.fuel_war_end
    capacity = c.industrial_fuel_capacity_kg_per_day
    demand = c.industrial_fuel_normal_demand_kg_per_day
    import_qty = 0.0
    if in_war:
        capacity *= c.fuel_war_capacity_factor
        demand = c.fuel_war_demand_kg_per_day
        war_day = day - c.fuel_war_start + 1
        if war_day <= c.industrial_fuel_import_days:
            import_qty = min(c.industrial_fuel_import_cap_kg_per_day, max(0, demand - capacity))

    reserve_usable = max(0.0, world.industrial_fuel_reserve_kg - c.industrial_fuel_safety_floor_kg)
    need_from_reserve = max(0.0, demand - capacity - import_qty)
    draw = min(reserve_usable, need_from_reserve)
    world.industrial_fuel_reserve_kg -= draw
    fulfilled = min(demand, capacity + import_qty + draw)
    return {
        "industrial_fuel_demand_kg": demand,
        "industrial_fuel_capacity_kg": capacity,
        "industrial_fuel_import_kg": import_qty,
        "industrial_fuel_reserve_draw_kg": draw,
        "industrial_fuel_fulfilled_kg": fulfilled,
        "industrial_fuel_fulfillment_rate": fulfilled / demand if demand else 1.0,
    }

# ---------------------------
# Bank algebra (separate deterministic unit tests)
# ---------------------------

def bank_capacity(equity: int = 1500, opening_fee: int = 40, three_period_ops: int = 72, min_operating_cash: int = 200, opening_from_capital: bool = True) -> int:
    fee = opening_fee if opening_from_capital else 0
    return equity - fee - three_period_ops - min_operating_cash

def bank_case(opening_from_capital: bool = True, loan_total: int = 1150) -> Dict[str, int]:
    equity = 1500
    deposits = 2000
    opening_fee = 40
    ops = 72
    min_cash = 200

    operating_cash = equity
    lifecycle_owner_cost = 0
    if opening_from_capital:
        operating_cash -= opening_fee
    else:
        lifecycle_owner_cost = opening_fee

    payment_reserve = deposits
    assert payment_reserve == deposits  # 100% payment reserve

    operating_cash -= loan_total
    assert operating_cash >= 0

    # No interim repayment assumption: all three period expenses must be survivable.
    operating_cash -= ops
    no_repayment_trough = operating_cash

    # Candidate 1,150 loan book:
    # 400@10%=40, 300@8%=24, 450@12%=54 => 118 interest.
    interest = 118 if loan_total == 1150 else int(round(loan_total * 0.10))
    operating_cash += loan_total + interest

    ending_equity = operating_cash
    bank_profit_vs_initial_equity = ending_equity - equity
    owner_lifecycle_profit = bank_profit_vs_initial_equity - lifecycle_owner_cost

    # Simultaneous withdrawal: all payment deposits can be paid from isolated reserve.
    withdrawal_paid = min(payment_reserve, deposits)
    payment_reserve -= withdrawal_paid
    deposit_liability_end = deposits - withdrawal_paid
    assert deposit_liability_end == 0
    assert payment_reserve == 0

    return {
        "equity_start": equity,
        "opening_fee": opening_fee,
        "opening_from_capital": int(opening_from_capital),
        "loan_total": loan_total,
        "payment_deposits": deposits,
        "payment_reserve_start": deposits,
        "three_period_ops": ops,
        "no_repayment_trough_cash": no_repayment_trough,
        "min_operating_cash_rule": min_cash,
        "interest_received": interest,
        "ending_equity_before_owner_external_fee": ending_equity,
        "bank_profit_vs_initial_equity": bank_profit_vs_initial_equity,
        "owner_lifecycle_profit": owner_lifecycle_profit,
        "simultaneous_withdrawal_paid": withdrawal_paid,
    }


def bank_bad_debt_case() -> Dict[str, int]:
    """Same 1,500 equity / fee-from-capital / 1,150 loan book.
    The 300-copper loan repays only 150 principal and pays no 24 interest.
    Payment deposits remain fully reserved and untouched.
    """
    equity = 1500
    opening_fee = 40
    deposits = 2000
    ops = 72
    operating_cash = equity - opening_fee
    payment_reserve = deposits

    # 400 + 300 + 450
    operating_cash -= 1150
    operating_cash -= ops
    trough = operating_cash
    assert trough == 238

    # Good loans: 400+40, 450+54. Bad 300 loan: only 150 principal.
    received = 440 + 504 + 150
    operating_cash += received
    ending_equity = operating_cash
    loss_vs_initial = ending_equity - equity

    # All payment depositors can still withdraw from separate reserve.
    withdrawal_paid = deposits
    payment_reserve -= withdrawal_paid
    assert payment_reserve == 0

    return {
        "equity_start": equity,
        "opening_fee_from_capital": opening_fee,
        "loan_total": 1150,
        "bad_loan_principal": 300,
        "bad_loan_recovery": 150,
        "foregone_bad_loan_interest": 24,
        "three_period_ops": ops,
        "no_repayment_trough_cash": trough,
        "ending_equity": ending_equity,
        "profit_loss_vs_initial_equity": loss_vs_initial,
        "payment_deposits": deposits,
        "simultaneous_withdrawal_paid": withdrawal_paid,
    }

# ---------------------------
# Scenario construction
# ---------------------------

def base_config() -> Config:
    c = Config()
    c.validate()
    return c

def scenario_configs() -> Dict[str, Config]:
    b = base_config()
    return {
        # Launch year: 2,000 fresh residents at day 0 + 20 replacements/day, half fresh/half transfers.
        "launch_base": b,

        # Launch shock: all initial 2,000 residents immediately realize the full 5,220 once-only package.
        # 2,000 * 5,220 = 10,440,000 copper realized at launch.
        "launch_2000_instant": replace(
            b,
            instant_initial_entitlement=True,
        ),

        # Steady-state full server. All 20 daily replacements are fresh.
        # Entitlement creation = 20 * 365 * 5,220 = 38,106,000 copper/year.
        # Realized mint is paced by activity unless instant_full_fresh_entitlement=True.
        "steady_fresh20": replace(
            b,
            fresh_share=1.0,
        ),

        # Hard monetary stress: all 20 replacements/day fresh and each immediately realizes all 5,220.
        "steady_fresh20_instant": replace(
            b,
            fresh_share=1.0,
            instant_full_fresh_entitlement=True,
        ),

        # 90-day nonfuel production halving, no repair.
        "supply_half_90_no_repair": replace(
            b,
            nonfuel_shock_start=60,
            nonfuel_shock_end=149,
            nonfuel_shock_factor=0.50,
        ),

        # Same shock but +1,500/day capacity after 20 days, paid from stabilizer cash.
        "supply_half_90_repair": replace(
            b,
            nonfuel_shock_start=60,
            nonfuel_shock_end=149,
            nonfuel_shock_factor=0.50,
            expansion_day=80,
            expansion_nonfuel_capacity=1500,
            expansion_cost=180_000,
        ),

        # Household/bed-service stress: bed capacity halved for 10 days.
        "bed_half_10": replace(
            b,
            nonfuel_shock_start=60,
            nonfuel_shock_end=69,
            bed_shock_factor=0.50,
        ),

        # Industrial fuel war from day 60 for 40 days.
        "fuel_war_40": replace(
            b,
            fuel_war_start=60,
            fuel_war_end=99,
            fuel_war_capacity_factor=0.50,
            fuel_war_demand_kg_per_day=15000,
        ),

        # Dormant money return stress.
        "dormant_return_200": replace(
            b,
            dormant_return_day=250,
            dormant_return_accounts=200,
        ),

        # All active players try to subscribe 100 copper into available player project capacity.
        "investment_heat": replace(
            b,
            all_active_investment_heat=True,
        ),
    }

# ---------------------------
# Initialization
# ---------------------------

def init_world(cfg: Config, seed: int, mature_initial: bool = False) -> World:
    cfg.validate()
    w = World(cfg=cfg, rng=random.Random(seed))

    if mature_initial:
        # Steady-state starting cohort: no new mint. Allocate their cash from existing
        # NPC business cash so total day-0 active money remains 7,000,000.
        # 800 copper each = 1.6m total, carved from producer/general/business buyers.
        # This is an allocation, not issuance.
        per = 800
        total = per * cfg.resident_cap
        pools = ["general_business_cash", "other_producer_cash", "transport_customer_cash", "industrial_customer_cash"]
        remain = total
        for name in pools:
            avail = getattr(w, name)
            take = min(avail, remain)
            setattr(w, name, avail - take)
            remain -= take
            if remain <= 0:
                break
        assert remain == 0, "insufficient day-0 system cash for mature cohort allocation"
        for _ in range(cfg.resident_cap):
            p = w.new_player("mature_initial", cash=per, mature=True)
            w.residents[p.pid] = p
    else:
        # Launch cohort: each has 5,220 entitlement created and receives only 180 entry mint now.
        for _ in range(cfg.resident_cap):
            p = w.new_player("fresh", cash=0, mature=False)
            w.create_fresh_entitlement(p, instant_full=cfg.instant_initial_entitlement)
            w.residents[p.pid] = p
    assert len(w.residents) == cfg.resident_cap
    return w

# ---------------------------
# One simulation
# ---------------------------

def run_simulation(name: str, cfg: Config, seed: int, mature_initial: bool = False) -> Tuple[List[Dict[str, object]], Dict[str, object]]:
    w = init_world(cfg, seed, mature_initial=mature_initial)

    rows: List[Dict[str, object]] = []
    previous_preserved = w.active_server_money() + w.archived_money()

    for day in range(1, cfg.days + 1):
        day_mint_before = w.cumulative_mint
        day_entitlement_before = w.cumulative_entitlement_created
        day_transfer_in_before = w.cumulative_transfer_in
        day_transfer_out_before = w.cumulative_transfer_out
        day_import_before = w.cumulative_import_outflow
        day_export_before = w.cumulative_export_inflow
        day_retire_before = w.cumulative_retirement
        day_j0_before = w.cumulative_j0_paid

        delivered_nf, delivered_hf = deliver_imports(w, day)
        industry_delivered = deliver_industry_orders(w, day)
        bike_retired, pump_retired = daily_durable_depreciation(w)
        transport_rev, industrial_rev = pay_customer_operating_revenue(w)

        expansion_paid = maybe_pay_expansion(w, day)

        # Replacements happen every day including day 1 in the full-server churn model.
        fresh_n, transfer_in_n, transfer_in_cash, transfer_out_cash, archived_out_cash = replace_residents(w, day)

        reactivated_cash = 0
        displaced_archive_cash = 0
        if day == cfg.dormant_return_day and cfg.dormant_return_accounts > 0:
            reactivated_cash, displaced_archive_cash = force_dormant_return(w, cfg.dormant_return_accounts)

        # Activity.
        active_ids = [pid for pid in list(w.residents.keys()) if w.rng.random() < cfg.activity_rate]
        dau = len(active_ids)
        econ_participants = sum(1 for pid in active_ids if w.residents[pid].role != "none")

        # Story reward receipts.
        story_claimed = 0
        for pid in active_ids:
            p = w.residents[pid]
            if p.origin == "fresh" and not cfg.instant_full_fresh_entitlement:
                story_claimed += claim_story_rewards(w, p)

        # Deficit-gated J0 transfer.
        j0_tasks, j0_paid = process_shared_j0(w, active_ids)

        # Protected basket.
        nf_capacity, hf_capacity, bed_capacity = capacities_for_day(w, day)
        basket = process_protected_basket(w, day, active_ids, nf_capacity, hf_capacity, bed_capacity)

        # Place one-day-lead imports after observing today's protected demand.
        ordered_nf, ordered_hf, import_prepay = order_imports(
            w, day, int(basket["protected_demand_total"]), nf_capacity, hf_capacity
        )

        # Cash-driven nonessential services.
        services = process_open_services(w, active_ids)

        # Durable customer stock / budgets / sector cash.
        industry = create_industry_cycle(w, day, active_ids)

        # Industrial fuel war model.
        fuel = process_industrial_fuel(w, day)

        active_money = w.active_server_money()
        archived_money = w.archived_money()
        preserved = active_money + archived_money

        day_mint = w.cumulative_mint - day_mint_before
        day_entitlement = w.cumulative_entitlement_created - day_entitlement_before
        day_transfer_in = w.cumulative_transfer_in - day_transfer_in_before
        day_transfer_out = w.cumulative_transfer_out - day_transfer_out_before
        day_import_outflow = w.cumulative_import_outflow - day_import_before
        day_export_inflow = w.cumulative_export_inflow - day_export_before
        day_retirement = w.cumulative_retirement - day_retire_before

        expected_preserved = (
            previous_preserved
            + day_mint
            + day_transfer_in
            - day_transfer_out
            - day_import_outflow
            + day_export_inflow
            - day_retirement
        )
        identity_error = preserved - expected_preserved
        if identity_error != 0:
            raise AssertionError(
                f"money identity error {identity_error} day {day} scenario {name} seed {seed}: "
                f"preserved={preserved}, expected={expected_preserved}"
            )
        previous_preserved = preserved

        assert w.stabilizer_cash >= 0
        assert w.recovery_fund_cash >= 0
        assert w.nonfuel_reserve >= -1e-9
        assert w.household_fuel_reserve_kg >= -1e-9
        assert w.industrial_fuel_reserve_kg >= -1e-9
        assert all(p.cash >= 0 for p in w.residents.values())

        # Role counts among active players for direct reconciliation of "60% no economy".
        role_counts = {r: 0 for r in ["none", "worker", "investor", "operator", "banker"]}
        for pid in active_ids:
            role_counts[w.residents[pid].role] += 1

        row: Dict[str, object] = {
            "scenario": name,
            "seed": seed,
            "day": day,
            "residents": len(w.residents),
            "dau": dau,
            "ccu_mean_est": dau * cfg.avg_hours_per_dau / 24.0,
            "ccu_peak_capacity_est": dau * cfg.avg_hours_per_dau / 24.0 * cfg.peak_ccu_multiplier,
            "econ_participants": econ_participants,
            "role_none": role_counts["none"],
            "role_worker": role_counts["worker"],
            "role_investor": role_counts["investor"],
            "role_operator": role_counts["operator"],
            "role_banker": role_counts["banker"],

            "fresh_in": fresh_n,
            "transfer_in_accounts": transfer_in_n,
            "transfer_in_cash": day_transfer_in,
            "transfer_out_cash": day_transfer_out,
            "archived_out_cash": archived_out_cash,
            "reactivated_cash": reactivated_cash,
            "displaced_to_archive_cash": displaced_archive_cash,

            "entitlement_created_today": day_entitlement,
            "entitlement_created_cum": w.cumulative_entitlement_created,
            "mint_today": day_mint,
            "mint_cum": w.cumulative_mint,
            "story_claimed_today": story_claimed,
            "j0_tasks": j0_tasks,
            "j0_paid_today": j0_paid,
            "j0_paid_cum": w.cumulative_j0_paid,

            "active_server_money": active_money,
            "archived_money": archived_money,
            "preserved_server_plus_archive_money": preserved,
            "money_identity_error": identity_error,

            "protected_basket_price": cfg.basket_price,
            **basket,

            "nonfuel_capacity_today": nf_capacity,
            "nonfuel_reserve": w.nonfuel_reserve,
            "imported_nonfuel_stock": w.imported_nonfuel_stock,
            "nonfuel_import_delivered": delivered_nf,
            "nonfuel_import_ordered": ordered_nf,
            "household_fuel_capacity_kg_today": hf_capacity,
            "household_fuel_reserve_kg": w.household_fuel_reserve_kg,
            "imported_household_fuel_stock_kg": w.imported_household_fuel_stock_kg,
            "household_fuel_import_delivered_kg": delivered_hf,
            "household_fuel_import_ordered_kg": ordered_hf,
            "import_prepay_today": import_prepay,
            "import_outflow_cum": w.cumulative_import_outflow,
            "stabilizer_cash": w.stabilizer_cash,
            "recovery_fund_cash": w.recovery_fund_cash,
            "expansion_paid_today": expansion_paid,

            **services,

            "bike_installed": w.bike_installed,
            "pump_installed": w.pump_installed,
            "bike_retired_today": bike_retired,
            "pump_retired_today": pump_retired,
            "transport_customer_cash": w.transport_customer_cash,
            "industrial_customer_cash": w.industrial_customer_cash,
            "bike_industry_cash": w.bike_industry_cash,
            "pump_industry_cash": w.pump_industry_cash,
            "order_escrow_cash": w.order_escrow_cash,
            **industry,
            **industry_delivered,

            **fuel,
            "industrial_fuel_reserve_kg": w.industrial_fuel_reserve_kg,
        }
        rows.append(row)

    fulfillment = [float(r["protected_fulfillment_rate"]) for r in rows]
    service_index = [float(r["open_service_price_index"]) for r in rows]
    fuel_fill = [float(r["industrial_fuel_fulfillment_rate"]) for r in rows]

    first_basket_fail = next((int(r["day"]) for r in rows if float(r["protected_fulfillment_rate"]) < 0.999999), None)
    first_fuel_fail = next((int(r["day"]) for r in rows if float(r["industrial_fuel_fulfillment_rate"]) < 0.999999), None)

    summary = {
        "scenario": name,
        "seed": seed,
        "days": cfg.days,
        "mature_initial": int(mature_initial),
        "min_basket_fulfillment": min(fulfillment),
        "first_basket_fail_day": first_basket_fail,
        "max_open_service_price_index": max(service_index),
        "min_industrial_fuel_fulfillment": min(fuel_fill),
        "first_industrial_fuel_fail_day": first_fuel_fail,
        "entitlement_created_cum": w.cumulative_entitlement_created,
        "mint_cum": w.cumulative_mint,
        "transfer_in_cum": w.cumulative_transfer_in,
        "transfer_out_cum": w.cumulative_transfer_out,
        "import_outflow_cum": w.cumulative_import_outflow,
        "export_inflow_cum": w.cumulative_export_inflow,
        "j0_paid_cum": w.cumulative_j0_paid,
        "active_server_money_end": w.active_server_money(),
        "archived_money_end": w.archived_money(),
        "preserved_money_end": w.active_server_money() + w.archived_money(),
        "stabilizer_cash_end": w.stabilizer_cash,
        "recovery_fund_cash_end": w.recovery_fund_cash,
        "nonfuel_reserve_end": w.nonfuel_reserve,
        "household_fuel_reserve_end_kg": w.household_fuel_reserve_kg,
        "industrial_fuel_reserve_end_kg": w.industrial_fuel_reserve_kg,
        "bike_installed_end": w.bike_installed,
        "pump_installed_end": w.pump_installed,
        "transport_customer_cash_end": w.transport_customer_cash,
        "industrial_customer_cash_end": w.industrial_customer_cash,
    }
    return rows, summary

# ---------------------------
# Output / checks
# ---------------------------

def write_csv(path: str, rows: List[Dict[str, object]]) -> None:
    if not rows:
        return
    fields = list(rows[0].keys())
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for row in rows:
            w.writerow(row)

def gold_fmt(copper: int) -> str:
    sign = "-" if copper < 0 else ""
    x = abs(int(copper))
    return f"{sign}{x // 100}g{x % 100:02d}c"

def analytic_checks() -> Dict[str, object]:
    # 20 completely fresh replacements per day, 365 days:
    annual_entitlement = 20 * 365 * FULL_FIRST_TIME_ENTITLEMENT
    assert annual_entitlement == 38_106_000

    # Correct normal-server player bicycle capital arithmetic:
    bike_cap = 14 * 1560
    hypothetical_700_demand = 700 * 100
    refund = hypothetical_700_demand - bike_cap
    accept = bike_cap / hypothetical_700_demand
    assert bike_cap == 21_840
    assert refund == 48_160
    assert abs(accept - 0.312) < 1e-12

    # 20 copper share percentages under all-equity project assumption.
    bike_share = 20 / 1560
    pump_share = 20 / 2880

    # Bank corrected no-interim-repayment maxima.
    max_external_opening_fee = bank_capacity(opening_from_capital=False)
    max_fee_from_capital = bank_capacity(opening_from_capital=True)
    assert max_external_opening_fee == 1228
    assert max_fee_from_capital == 1188

    return {
        "annual_entitlement_20_fresh_per_day": annual_entitlement,
        "normal_player_bike_capital_14_batches": bike_cap,
        "hypothetical_700_x_100_demand": hypothetical_700_demand,
        "refund_if_700_all_offer_100": refund,
        "acceptance_rate_if_700_all_offer_100": accept,
        "20_copper_share_of_1560_project": bike_share,
        "20_copper_share_of_2880_project": pump_share,
        "bank_max_loan_opening_fee_external": max_external_opening_fee,
        "bank_max_loan_opening_fee_from_capital": max_fee_from_capital,
        "bank_case_fee_from_capital_1150": bank_case(True, 1150),
        "bank_case_fee_external_1150": bank_case(False, 1150),
        "bank_bad_debt_case": bank_bad_debt_case(),
    }

def main() -> None:
    outdir = os.path.join(os.path.dirname(__file__), "mistport_2000_results")
    os.makedirs(outdir, exist_ok=True)

    checks = analytic_checks()
    with open(os.path.join(outdir, "analytic_checks.json"), "w", encoding="utf-8") as f:
        json.dump(checks, f, ensure_ascii=False, indent=2)

    scenarios = scenario_configs()
    seeds = [1, 2, 3, 4, 5]
    all_daily: List[Dict[str, object]] = []
    all_summary: List[Dict[str, object]] = []

    for name, cfg in scenarios.items():
        # Steady churn scenarios start with a mature resident cohort whose money is a day-0 allocation,
        # not a new launch mint. Other scenarios are launch-year scenarios.
        mature_initial = name.startswith("steady_")
        for seed in seeds:
            rows, summary = run_simulation(name, cfg, seed, mature_initial=mature_initial)
            all_daily.extend(rows)
            all_summary.append(summary)

    write_csv(os.path.join(outdir, "daily_all_scenarios.csv"), all_daily)
    write_csv(os.path.join(outdir, "summary_all_scenarios.csv"), all_summary)

    # Also emit seed-1 daily files per scenario for convenient auditing
    # without rerunning the simulations.
    for name in scenarios:
        seed1_rows = [r for r in all_daily if r["scenario"] == name and int(r["seed"]) == 1]
        write_csv(os.path.join(outdir, f"daily_{name}_seed1.csv"), seed1_rows)

    # Bank tables.
    bank_rows = [
        {"case": "max_loan_opening_fee_external", "value": bank_capacity(opening_from_capital=False)},
        {"case": "max_loan_opening_fee_from_capital", "value": bank_capacity(opening_from_capital=True)},
    ]
    write_csv(os.path.join(outdir, "bank_capacity.csv"), bank_rows)

    bank_cases = [
        ("opening_fee_from_capital", bank_case(True, 1150)),
        ("opening_fee_external", bank_case(False, 1150)),
        ("bad_debt_300_recovers_150", bank_bad_debt_case()),
    ]
    bank_case_rows: List[Dict[str, object]] = []
    all_fields = set(["case"])
    for _, case in bank_cases:
        all_fields.update(case.keys())
    fields = ["case"] + sorted(k for k in all_fields if k != "case")
    with open(os.path.join(outdir, "bank_cases.csv"), "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for name_, case in bank_cases:
            writer.writerow({"case": name_, **case})

    # Print compact deterministic report.
    print("ANALYTIC_CHECKS")
    print(json.dumps(checks, ensure_ascii=False, indent=2))
    print("\nSUMMARY (seed=1)")
    for s in all_summary:
        if int(s["seed"]) == 1:
            print(
                s["scenario"],
                "basket_min=", round(float(s["min_basket_fulfillment"]), 6),
                "basket_fail_day=", s["first_basket_fail_day"],
                "open_service_max_idx=", round(float(s["max_open_service_price_index"]), 3),
                "fuel_min=", round(float(s["min_industrial_fuel_fulfillment"]), 6),
                "fuel_fail_day=", s["first_industrial_fuel_fail_day"],
                "entitlement_created=", s["entitlement_created_cum"],
                "mint=", s["mint_cum"],
                "active_money_end=", s["active_server_money_end"],
            )

if __name__ == "__main__":
    main()
