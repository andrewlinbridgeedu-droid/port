"""Lodging extension of bank_check: leases, finite client orders and rent transfers.
The server layer uses campaign costs and V3 receipt progress; it does not replay fights.
"""
from __future__ import annotations
import argparse
from dataclasses import dataclass, replace
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import gzip
import json
import bank_check as b

@dataclass(frozen=True)
class HousingCase(b.Case):
    housing: str = 'basic'
    prices: tuple = (12,18,26,30,50)
    meetings: bool = True
    failed_meetings: bool = False
    demand_share: float = 1.
    customer_account: str = "general_business_cash"

HOUSE = None
ORIG_INIT = b.init_bank
ORIG_MONEY = b.server_money
ORIG_LOOP = b.bank_loop

def init_housing(cfg, seed, mature_initial=False):
    global HOUSE
    w = ORIG_INIT(cfg, seed, mature_initial)
    HOUSE = dict(leases={}, pending=[], escrow=0, premium_paid=0, meeting_paid=0,
                 contract_gross=0, contract_inputs=0, contracts=0, deliveries=0,
                 client_denials=0, budget_denials=0, failed_meetings=0,
                 meeting_weeks=set(), order_weeks=set(), tier_days={str(i):0 for i in range(5)},
                 rooms_peak={str(i):0 for i in range(1,5)}, housing_late_material_accounts=set())
    return w

def money(w):
    return ORIG_MONEY(w) + HOUSE['escrow']

def tier_unlocked(p):
    return 4 if p.q_completed>=30 else 3 if p.q_completed>=20 else 2 if p.q_completed>=13 else 1 if p.q_completed>=5 else 0

def housing_loop(w, active_ids):
    ORIG_LOOP(w,active_ids)
    day=b.sd.TODAY
    for c in list(HOUSE['pending']):
        if c['due']<=day:
            b.pay_player(w,c['p'],c['gross']); HOUSE['escrow']-=c['gross']
            HOUSE['contract_gross']+=c['gross']; HOUSE['deliveries']+=1; HOUSE['pending'].remove(c)
    # Occupancy persists through offline days and expires at the 7-day lease boundary.
    occupied={i:0 for i in range(1,5)}
    for pid,l in list(HOUSE['leases'].items()):
        if pid not in w.residents or l['until']<=day:
            HOUSE['leases'].pop(pid)
        elif l['tier']>0: occupied[l['tier']]+=1
    capacity={1:1200,2:600,3:200,4:80}
    for pid in sorted(active_ids,key=lambda i:(-w.residents[i].cash,i)):
        p=w.residents[pid]; prices=b.CASE.prices
        old=HOUSE['leases'].get(pid)
        wanted=tier_unlocked(p) if b.CASE.housing!='basic' else 0
        if b.CASE.housing=='budget':
            while wanted>0 and p.cash+b.principal(p,'deposit')<b.reserve(p)+7*prices[wanted]: wanted-=1
        if old and old['tier']>0: occupied[old['tier']]-=1
        while wanted>0 and occupied[wanted]>=capacity[wanted]: wanted-=1
        if old and wanted==old['tier']: HOUSE['leases'][pid]=old
        else: HOUSE['leases'][pid]=dict(tier=wanted,until=day+7)
        if wanted: occupied[wanted]+=1
        tier=wanted
        while tier>0 and p.cash+b.principal(p,'deposit')<prices[tier]+36: tier-=1
        extra=prices[tier]-12
        if extra:
            b.redeem(w,p,extra+48)
            assert p.cash>=extra+12
            p.cash-=extra;w.general_business_cash+=extra;HOUSE['premium_paid']+=extra
        HOUSE['tier_days'][str(tier)]+=1
        if tier>0 and len(b.BANK['materials'].get(pid,set()))<4 and p.q_completed>=30:
            HOUSE['housing_late_material_accounts'].add(pid)
        if not b.CASE.meetings or p.q_completed<13 or pid%1000>=int(b.CASE.demand_share*1000): continue
        week=(day-1)//7; key=(pid,week)
        reserve=b.reserve(p) if b.CASE.housing=='budget' else 36
        if key not in HOUSE['meeting_weeks']:
            fee=(2,2,4,6,10)[tier]
            if p.cash<reserve+fee: HOUSE['budget_denials']+=1;continue
            p.cash-=fee;w.general_business_cash+=fee;HOUSE['meeting_paid']+=fee
            HOUSE['meeting_weeks'].add(key)
            if b.CASE.failed_meetings: HOUSE['failed_meetings']+=1;continue
        if b.CASE.failed_meetings or key in HOUSE['order_weeks']: continue
        gross=(40,40,60,60,96)[tier];inputs=(20,20,30,30,50)[tier]
        if p.cash<reserve+inputs: HOUSE['budget_denials']+=1;continue
        # Dye shops, collectors and ordinary merchants pay from existing business cash.
        if getattr(w,b.CASE.customer_account)<gross: HOUSE['client_denials']+=1;continue
        setattr(w,b.CASE.customer_account,getattr(w,b.CASE.customer_account)-gross);HOUSE['escrow']+=gross
        p.cash-=inputs;w.general_business_cash+=inputs;HOUSE['contract_inputs']+=inputs
        HOUSE['order_weeks'].add(key);HOUSE['contracts']+=1
        HOUSE['pending'].append(dict(p=p,gross=gross,due=day+1))
    for tier,n in occupied.items():
        assert n<=capacity[tier]
        HOUSE['rooms_peak'][str(tier)]=max(HOUSE['rooms_peak'][str(tier)],n)
    assert HOUSE['escrow']==sum(c['gross'] for c in HOUSE['pending'])

def read(path):
    p=Path(path)
    if p.exists(): return json.loads(p.read_text())
    with gzip.open(str(p)+'.gz','rt') as f:return json.load(f)

def rates(rows,mode):
    r=next(r for r in rows if r['profile']=='medium' and r['policy']=='all' and r['startOffset']==0
           and r['bankExperiment']['scenario']['name'].split('_')[1]==mode
           and r['bankExperiment']['scenario']['name'].endswith('_none'))
    h=r['housingExperiment'];day=r['bankExperiment']['storyDay']
    assert h.get('chapterIncome') is not None, mode
    src=h['chapterIncome'];chapter={name:src.get(key,0)/day for name,key in [('orders','workshop'),('errands','errand'),('remnants','remnant'),('events','event')]}
    stock=chapter['orders']*.5
    spending=180+sum(src.values())-h['chapterCash']
    other=spending-h.get('chapterAdvancementPaid',r['bankExperiment']['advancementSpent'])-h['chapterLiving']-stock*day-h['chapterSpending']['meeting']-h['chapterSpending']['contract_inputs']
    assert other>=0,(mode,other)
    return dict(chapter=chapter,chapter_stock=stock,post=dict(chapter,orders=9.,remnants=4.5,events=0.,errands=chapter['errands']+5.04),
                post_stock=4.5,source_days=day,campaign_cost_total=other,campaign_cost_per_receipt=other/len(b.v3.REWARD_QUEUE))

def job(args):
    case,seed,days,rate=args
    b.init_bank=init_housing;b.server_money=money;b.bank_loop=housing_loop
    out=b.run_job((case,seed,days,rate))
    out['housing']={k:v for k,v in HOUSE.items() if k not in ['leases','pending','meeting_weeks','order_weeks','housing_late_material_accounts']}
    out['housing'].update(leases=len(HOUSE['leases']),open_contracts=len(HOUSE['pending']),
        late_material_accounts=len(HOUSE['housing_late_material_accounts']),contract_net=HOUSE['contract_gross']-HOUSE['contract_inputs']-HOUSE['meeting_paid'])
    out['housing_rules']=dict(strategy=case.housing,prices=case.prices,meetings=case.meetings,failed_meetings=case.failed_meetings,customer_account=case.customer_account)
    return out

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--campaign',required=True);ap.add_argument('--out',required=True)
    ap.add_argument('--days',type=int,default=365);ap.add_argument('--seeds',default='1,2,3');ap.add_argument('--workers',type=int,default=3)
    ap.add_argument('--costs',default='12,18,26,30,50');ap.add_argument('--cases',default='')
    a=ap.parse_args();prices=tuple(map(int,a.costs.split(',')));assert len(prices)==5 and prices[0]==12
    rows=read(a.campaign)
    cases=[HousingCase('basic',housing='basic'),HousingCase('budget',housing='budget'),HousingCase('greedy',housing='greedy'),
        HousingCase('budget_loss160',housing='budget',bonus=12,risk=160,repayment_percent=0),
        HousingCase('budget_supply_repair',housing='budget',base='supply_half_90_repair',expansion=2000),
        HousingCase('budget_supply_unrepaired',housing='budget',base='supply_half_90_no_repair'),
        HousingCase('budget_guests25pct',housing='budget',demand_share=.25),
        HousingCase('budget_guests_failed',housing='budget',failed_meetings=True),
        HousingCase('budget_no_guests',housing='budget',meetings=False)]
    if a.cases:cases=[c for c in cases if c.name in a.cases.split(',')]
    jobs=[(replace(c,prices=prices,earned_materials=True,recovery_fund=960000),seed,a.days,rates(rows,c.housing)) for c in cases for seed in map(int,a.seeds.split(','))]
    dest=Path(a.out);dest.mkdir(parents=True,exist_ok=True);result=[]
    with ProcessPoolExecutor(max_workers=a.workers) as pool:
        for r in pool.map(job,jobs):
            result.append(r);print(r['ext']['name'],r['seed'],'L1/L2/L3',r['L1'],r['L2_strict'],r['L3'],'rent',r['housing']['premium_paid'],'client_denied',r['housing']['client_denials'],flush=True)
            (dest/'results.json').write_text(json.dumps(dict(days=a.days,results=result),ensure_ascii=False,indent=2))
if __name__=='__main__': main()
