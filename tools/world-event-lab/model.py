"""Mistport design lab. Hypotheses only; no game saves or reward mutations.

Public outcomes: seeded Monte Carlo. Conditional four-stage race: exact DP.
Project ledger: finite buyer wallet / inputs. Currency: issuance accounting,
not a price, inflation, wealth-distribution or endogenous market model.
"""
import math
import random
from collections import Counter, defaultdict
from functools import lru_cache

VERSION = 'lights-lab-1.0'
DEFAULTS = dict(
    players=2000, participants=400, share_a=.7,
    public_a=.65, public_b=.65, hard_a=0, hard_b=0,
    hard_success_a=.45, hard_success_b=.45,
    node_a=.5, node_b=.5, boss_a=.5, boss_b=.5, attendance=.85,
    funding_a=1200, funding_b=1200, supply_a=12, supply_b=12,
    kit_price=40, kit_cost=34, craft_minutes=6,
    orders_a=50, orders_b=50, buyer_budget=6000, raw_capacity=50,
    public_doses=.3, core_doses=1, launch_guard=False,
    dau=.55, monthly=.3, base=6, bonus=12, q_participation=1,
    q_runs=1, q_minutes=8, q_cost=15, other_cash=8,
    craft_participation=.6, crafts=1, sale_rate=.7, sale_price=70,
    craft_sink=14, fee=.05, other_sink=2.3, fresh=0,
    external_sink=True, newcomer_sink=True, fixed_active_cohort=False, seed=270927, trials=2000)

# Strictly bounded local API inputs; statistical probabilities are assumptions.
RANGES = {
    'players':(1,10000), 'participants':(0,2000), 'share_a':(0,1),
    'funding_a':(0,1200), 'funding_b':(0,1200),
    'supply_a':(0,12), 'supply_b':(0,12), 'kit_price':(1,150),
    'kit_cost':(0,200), 'craft_minutes':(.1,60),
    'orders_a':(0,200), 'orders_b':(0,200), 'buyer_budget':(0,100000),
    'raw_capacity':(0,50), 'public_doses':(0,3), 'core_doses':(0,3),
    'base':(0,100), 'bonus':(0,100), 'q_runs':(1,20),
    'q_minutes':(1,60), 'q_cost':(0,105), 'other_cash':(0,100),
    'crafts':(0,10), 'sale_price':(1,1000), 'craft_sink':(0,100),
    'other_sink':(0,100), 'fresh':(0,20), 'seed':(0,2**32-1),
    'trials':(200,10000)}
INTS = {'players','participants','funding_a','funding_b','supply_a','supply_b',
        'kit_price','kit_cost','orders_a','orders_b','buyer_budget','raw_capacity',
        'q_runs','fresh','seed','trials'}


def config(values=None):
    if values is not None and not isinstance(values, dict):
        raise ValueError('parameters must be an object')
    if set(values or {}) - set(DEFAULTS):
        raise ValueError('unknown parameter')
    p = {**DEFAULTS, **(values or {})}
    for k,v in p.items():
        if isinstance(DEFAULTS[k],bool):
            if type(v) is not bool: raise ValueError(k + ': boolean required')
            continue
        lo,hi = RANGES.get(k,(0,1))
        if type(v) not in (int,float) or not math.isfinite(v) or not lo <= v <= hi:
            raise ValueError(k + ': outside allowed range')
        if k in INTS and int(v) != v: raise ValueError(k + ': integer required')
        if k in INTS: p[k]=int(v)
    if p['participants'] > p['players']:
        raise ValueError('event participants cannot exceed registered players')
    return p


def engineering(funding, supply, price):
    installed = min(12, supply, int(funding // price))
    return dict(installed=installed, spent=installed*price,
                cash=funding-installed*price, ready=installed==12)


def allocation(wins, points, ready):
    qualified = tuple(ready[i] and wins[i]>=4 for i in (0,1))
    if qualified == (False,False): return (0,0),None,qualified
    if qualified == (True,False): caps,leader=(6,0),'A'
    elif qualified == (False,True): caps,leader=(0,6),'B'
    else:
        leader='A' if points[0]>points[1] else 'B' if points[1]>points[0] else None
        caps=(6,4) if leader=='A' else (4,6) if leader=='B' else (5,5)
    return tuple(min(c,w) for c,w in zip(caps,wins)),leader,qualified


def contract(outcome, leader, qualified):
    # A/B = successful attacker; it is the OTHER side's leader who dies.
    if outcome == 'both': return 'interim'
    if outcome == 'A': return 'A' if qualified[0] else 'interim'
    if outcome == 'B': return 'B' if qualified[1] else 'interim'
    if outcome != 'neither': raise ValueError('unknown mortality outcome')
    if leader == 'A' and qualified[0]: return 'A'
    if leader == 'B' and qualified[1]: return 'B'
    return 'interim'


@lru_cache(maxsize=2048)
def race(caps, nodes, bosses, attendance):
    """Three node successes then a duel, distinct candidates, same-wave closure.

    Unfilled opportunity consumes its wave; no extra world attempt. The DP stops
    after first lethal wave. Stage difficulty switches only after 3 successes.
    """
    states={(0,0):1.0}
    out=dict(A=0., B=0., both=0., neither=0.)
    starts=0.
    for wave in range(1,max(caps)+1):
        following=defaultdict(float)
        for (a,b), mass in states.items():
            options=[]
            for i,stage in enumerate((a,b)):
                eligible=wave<=caps[i]
                starts += mass*attendance if eligible else 0
                prob=(nodes[i] if stage<3 else bosses[i])*attendance if eligible else 0
                options.append(((0,1-prob),(1,prob)))
            for da,pa in options[0]:
                for db,pb in options[1]:
                    na,nb=a+da,b+db
                    m=mass*pa*pb
                    if na>=4 and nb>=4: out['both']+=m
                    elif na>=4: out['A']+=m
                    elif nb>=4: out['B']+=m
                    else: following[(na,nb)]+=m
        states=following
    out['neither']=sum(states.values())
    assert abs(sum(out.values())-1)<1e-10
    return out,starts


def simulate_event(p):
    rng=random.Random(p['seed'])
    n_a=int(p['participants']*p['share_a']+.5)
    ns=(n_a,p['participants']-n_a)
    eng=[engineering(p['funding_'+s],p['supply_'+s],p['kit_price']) for s in ('a','b')]
    counts=Counter()
    means=[0.,0.]
    for _ in range(p['trials']):
        wins=[]; points=[]
        for i,s in enumerate(('a','b')):
            hard=int(ns[i]*p['hard_'+s]+.5)
            normal=ns[i]-hard
            wn=sum(rng.random()<p['public_'+s] for _ in range(normal))
            wh=sum(rng.random()<p['hard_success_'+s] for _ in range(hard))
            wins.append(wn+wh); points.append(wn+2*wh)
            means[i]+=points[-1]/p['trials']
        caps,leader,qualified=allocation(wins,points,tuple(e['ready'] for e in eng))
        counts[(caps,leader,qualified)]+=1
    outcomes=dict(A=0.,B=0.,interim=0.)
    mortality=dict(A=0.,B=0.,both=0.,neither=0.)
    starts=0.; gates=[0.,0.]; opportunities=[0.,0.]
    for (caps,leader,qualified),count in counts.items():
        weight=count/p['trials']
        r,attempts=race(caps,(p['node_a'],p['node_b']),
                        (p['boss_a'],p['boss_b']),p['attendance'])
        for k,mass in r.items():
            outcomes[contract(k,leader,qualified)]+=weight*mass
            mortality[k]+=weight*mass
        starts+=weight*attempts
        for i in (0,1):
            gates[i]+=weight*qualified[i]
            opportunities[i]+=weight*caps[i]
    # Individual bounded-mean Hoeffding bound, not a claim about real players.
    margin=math.sqrt(math.log(40)/(2*p['trials']))
    return dict(roster=ns, scores=means, outcomes=outcomes, mortality=mortality,
                qualified=gates, opportunities=opportunities, core_starts=starts,
                sample_bound95=margin, engineering=eng,
                doses=p['participants']*p['public_doses']+starts*p['core_doses'])


def operate(p,side):
    funding=p['funding_'+side]
    e=engineering(funding,p['supply_'+side],p['kit_price'])
    project=e['cash']; buyers=p['buyer_budget']; crafts=e['spent']; external=0
    dividends=0; fulfilled=0; operating_days=0; rows=[]
    # Optional first-test guard: first seven input days represent paid,
    # input-backed, reserved orders, not merely interested customers.
    prebook_wallet=buyers;prebook_net=0
    for _ in range(7):
        qty=min(p['orders_'+side],50,p['raw_capacity'],int(prebook_wallet//4))
        revenue=qty*4
        if qty and revenue>=p['kit_price']+60:
            prebook_wallet-=revenue
            prebook_net+=revenue-p['kit_price']-60
    can_start=e['ready'] and project>=120 and (not p['launch_guard'] or prebook_net>=120)
    if can_start: project-=120;external+=120
    daily_cost=p['kit_price']+60
    for day in range(1,31):
        quantity=min(p['orders_'+side],50,p['raw_capacity'],int(buyers//4))
        revenue=quantity*4
        if not can_start or quantity==0 or revenue<daily_cost:
            quantity=0;revenue=0;cost=0;dist=0
        else:
            # Prepaid fulfilled batch. Materials cover these orders; no phantom sale.
            cost=daily_cost;buyers-=revenue;crafts+=p['kit_price'];external+=60
            net=revenue-cost;dist=net/2
            project+=net-dist;dividends+=dist;fulfilled+=quantity;operating_days+=1
        total=project+buyers+crafts+external+dividends
        assert abs(total-(funding+p['buyer_budget']))<1e-8
        rows.append(dict(day=day,orders=quantity,revenue=revenue,cost=cost,
                         distribution=dist,project=project,buyers=buyers,
                         investor_net=project+dividends-funding))
    return dict(ready=e['ready'], can_start=can_start, prebook_net=prebook_net, construction=e['spent'],
                refund_if_loses=e['cash'], loss_if_loses=-e['spent'],
                refund_if_wins=project, dividends=dividends,
                net_if_wins=project+dividends-funding,
                fulfilled=fulfilled, operating_days=operating_days,
                buyers_left=buyers, crafts=crafts, external=external,
                conservation_error=project+buyers+crafts+external+dividends-funding-p['buyer_budget'],
                break_even_orders=math.ceil(daily_cost/4), rows=rows)


def q_issuance(p,days,interval):
    """Fixed global windows, each account at most one cash claim/window.

    Each day account has independent P(active AND choosing Q30). Unlimited
    mode permits q_runs on those days. Finite windows ignore extra replays.
    """
    reach=p['dau']*p['q_participation']
    if interval==1: return p['players']*reach*p['q_runs']*105*days
    full,remainder=divmod(days,interval)
    if p['fixed_active_cohort']:
        # Same DAU accounts every day; remaining accounts never claim.
        reach=p['q_participation']
        claims=full*(1-(1-reach)**interval)+(1-(1-reach)**remainder)
        return p['players']*p['dau']*105*claims
    claims=full*(1-(1-reach)**interval)+(1-(1-reach)**remainder)
    return p['players']*105*claims


def money(p,days,interval):
    active=p['players']*p['dau']
    base=active*(p['base']+p['monthly']*p['bonus'])*days
    q=q_issuance(p,days,interval)
    other=active*p['other_cash']*days
    newcomers=p['fresh']*5220*days
    pieces=active*p['craft_participation']*p['crafts']*days
    gross=pieces*p['sale_rate']*p['sale_price']
    materials=pieces*p['craft_sink']
    fees=gross*p['fee']
    sinks=(materials if p['external_sink'] else 0)+fees+active*p['other_sink']*days
    newcomer_out=p['fresh']*1080*days if p['newcomer_sink'] else 0
    recurring=q+base+other-sinks
    return dict(days=days,interval=interval,q=q,base=base,other=other,
                newcomers=newcomers, sinks=sinks+newcomer_out,
                recurring_net=recurring,net=recurring+newcomers-newcomer_out,
                gross=gross,material_payments=materials,fees=fees,
                pressure=recurring/gross if gross else None,
                break_even_sink_per_active_day=(q+base+other)/(active*days) if active and days else None,
                actual_sink_per_active_day=sinks/(active*days) if active and days else None)


def run(values=None):
    p=config(values)
    event=simulate_event(p)
    projects=[operate(p,s) for s in ('a','b')]
    for i,s in enumerate(('A','B')):
        projects[i]['expected_net']=event['outcomes'][s]*projects[i]['net_if_wins'] + (1-event['outcomes'][s])*projects[i]['loss_if_loses']
    matrix=[money(p,days,interval) for days in (180,365,730) for interval in (1,7,14)]
    chart=[dict(day=d,values=[money(p,d,k)['net'] for k in (1,7,14)]) for d in range(0,731,10)]
    event['components_installed']=sum(x['installed'] for x in event['engineering'])*6
    event['expected_service_kits']=sum(event['outcomes'][s]*projects[i]['operating_days'] for i,s in enumerate(('A','B')))
    return dict(version=VERSION,params=p,event=event,projects=projects,money=matrix,chart=chart,
                craft=dict(margin=p['kit_price']-p['kit_cost'],
                           rpm=(p['kit_price']-p['kit_cost'])/p['craft_minutes']),
                q_rpm=(105-p['q_cost'])/p['q_minutes'])
