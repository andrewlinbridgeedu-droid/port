"""Offline v3 candidate settlement. Not wired into live saves or game rewards."""
from dataclasses import dataclass


@dataclass
class Wallet:
    cash: int
    crafted: int = 0
    system_bound: int = 0
    legacy_unknown: int = 0
    shop_unlocked: bool = True


@dataclass
class Ledger:
    system_retired: int = 0
    trade_retired: int = 0
    trade_fee_remainder: int = 0
    player_gross: int = 0
    player_sales: int = 0
    guarantee_purchases: int = 0


def buy_guarantee(a, ledger):
    if not a.shop_unlocked or a.cash < 30 or a.crafted+a.system_bound+a.legacy_unknown:
        return False
    a.cash -= 30
    a.system_bound += 1
    ledger.system_retired += 30
    ledger.guarantee_purchases += 1
    return True


def transfer_crafted(seller, buyer, quantity, unit_price, ledger):
    if seller is buyer or quantity <= 0 or unit_price <= 0:
        return False
    gross = quantity * unit_price
    if seller.crafted < quantity or buyer.cash < gross:
        return False
    # Whole-copper settlement with fee remainder; splitting orders cannot erase fees.
    fee, remainder = divmod(gross*5+ledger.trade_fee_remainder, 100)
    seller.crafted -= quantity
    buyer.crafted += quantity
    buyer.cash -= gross
    seller.cash += gross-fee
    ledger.trade_retired += fee
    ledger.trade_fee_remainder = remainder
    ledger.player_gross += gross
    ledger.player_sales += quantity
    return True


def deliver_event(a, quantity):
    # Returns eligible physical delivery only; event funding is a separate transaction.
    if quantity <= 0 or a.crafted < quantity:
        return False
    a.crafted -= quantity
    return True


def satisfy(a, demand, ledger, offers=()):
    """One-dose self-use decisions; offers are actual (seller, price) pairs.

    Demand is exogenous, never manufactured to create a sink. Existing unknown
    stock stays usable but is excluded from craft attribution and trading.
    This does not model combat timing or permit mid-combat shop access.
    """
    assert demand >= 0
    out = dict(demand=demand, craft_used=0, guarantee_used=0, legacy_used=0,
               unmet=0, unmet_affordability=0, unmet_access_or_supply=0)
    for _ in range(demand):
        if a.system_bound:
            a.system_bound -= 1; out['guarantee_used'] += 1
        elif a.legacy_unknown:
            a.legacy_unknown -= 1; out['legacy_used'] += 1
        elif a.crafted:
            a.crafted -= 1; out['craft_used'] += 1
        else:
            fallback = a.shop_unlocked and a.cash >= 30
            eligible = [(s,p) for s,p in offers if s is not a and s.crafted > 0
                        and 0 < p <= a.cash and (not fallback or p <= 30)]
            if eligible:
                seller,price = min(eligible,key=lambda x:x[1])
                assert transfer_crafted(seller,a,1,price,ledger)
                a.crafted -= 1; out['craft_used'] += 1
            elif buy_guarantee(a,ledger):
                a.system_bound -= 1; out['guarantee_used'] += 1
            else:
                out['unmet'] += 1
                prices = [p for s,p in offers if s is not a and s.crafted > 0 and p > 0]
                if a.shop_unlocked: prices.append(30)
                key = 'unmet_affordability' if prices and min(prices)>a.cash else 'unmet_access_or_supply'
                out[key] += 1
    assert sum(out[k] for k in ('craft_used','guarantee_used','legacy_used','unmet')) == demand
    for name,num in [('craft_fill',out['craft_used']),('guarantee_fill',out['guarantee_used']),
                     ('legacy_fill',out['legacy_used']),('total_fill',demand-out['unmet'])]:
        out[name] = num/demand if demand else None
    return out
