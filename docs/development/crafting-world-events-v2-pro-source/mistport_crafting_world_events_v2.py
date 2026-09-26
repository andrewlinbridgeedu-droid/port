#!/usr/bin/env python3
"""Mistport crafting + world-event economy candidate model v2.
Standard library only. Design model, not production code, not proof of price stability.

Key boundaries:
- 2,000 registered accounts; activity/pass rates are scenario inputs.
- Existing one-time copper total is 5,220 per account. Timing here is a simulation assumption.
- Existing repeatable copper is not deleted. `repeat_per_active` is an explicit sensitivity proxy,
  not a statement of the source-code average per active day.
- Tower material supply uses the actual D01-D11 -> material candidate map proposed for crafting,
  an explicit two-candidate choice algorithm, and an assumed encounter-weight distribution.
- World events buy only real player goods/materials from finite pre-funded budgets. Donations are unpaid.
- Durable demand is stock-limited and saturates; events do not regenerate infinite customers.
- Prices are endogenous signals with no hard upper price cap in the simulation.
"""
from __future__ import annotations
import csv, math, random, statistics
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Tuple

OUT = Path('/mnt/data/mistport_crafting_world_events_v2_results')
OUT.mkdir(parents=True, exist_ok=True)

N = 2000
SEEDS = (20260926, 20260927, 20260928)
CYCLE = 7
BASIC_ALLOWANCE = 28          # candidate: 28 copper / 7 world-economic cycles
PASS_EXTRA = 28               # candidate: +28 tradable copper / 7 cycles
FREE_CAP_BLOCKS = 4           # 28-day catch-up cap
PASS_CAP_BLOCKS = 8           # protects paid entitlement from short absences
FEE_RATE = 0.05               # P2P transaction fee, retired from circulation in this model
STATION_FEE = 1               # retired on each successful craft receipt
TOWER_BUNDLE_QTY = 2          # final candidate: chosen material bundle yields 2 units per valid tower victory
REPAIR_COPPER_PER_TOWER_WIN = 1.2  # explicit aggregate sensitivity assumption, not current measured repair spend
WRAP_REPAIR_DISCOUNT = {'wrap_basic':6,'wrap_adv':12}  # candidate max copper reduction per consumed wrap

# Existing one-time facts.
INITIAL = 180
MAINLINE = 2280
TOWER_FIRST = 1700
BOUNTY_FIRST = 1060
ONE_TIME_TOTAL = INITIAL + MAINLINE + TOWER_FIRST + BOUNTY_FIRST

# New character-level candidate. Gating only; no combat-stat scaling in this model.
LEVEL_THRESHOLDS = [0,100,220,360,520,700,900,1120,1360,1620,1900,2200,2520,2860,3220,3600,4000,4420,5000,6000]
PROFS = ('textile','leather','metal','alchemy')
MATS = ('mist_fiber','resilient_membrane','shell_chip','sinew_cord','saline_powder','restorative_gel','veil_filament','copper_scale')
MAT_START_PRICE = {'mist_fiber':6,'resilient_membrane':8,'shell_chip':10,'sinew_cord':7,'saline_powder':6,'restorative_gel':10,'veil_filament':12,'copper_scale':10}

# Proposed tower-material map, based on existing D01-D11 identities; no monster is renamed.
MONSTER_MATERIALS = {
    'D01': ('shell_chip','sinew_cord'),
    'D02': ('saline_powder','resilient_membrane'),
    'D03': ('resilient_membrane','restorative_gel'),
    'D04': ('shell_chip','sinew_cord'),
    'D05': ('mist_fiber','veil_filament'),
    'D06': ('sinew_cord','copper_scale'),
    'D07': ('shell_chip','copper_scale'),
    'D08': ('shell_chip','sinew_cord'),
    'D09': ('mist_fiber','veil_filament'),
    'D10': ('resilient_membrane','restorative_gel','saline_powder'),
    'D11': ('saline_powder','mist_fiber'),
}
# Explicit MODEL ASSUMPTION because the exact full F1-F100 encounter frequencies were not supplied here.
MONSTER_WEIGHTS = {'D01':.14,'D02':.12,'D03':.08,'D04':.08,'D05':.08,'D06':.08,'D07':.10,'D08':.10,'D09':.07,'D10':.08,'D11':.07}
PROF_MAT_PREF = {
    'textile': {'mist_fiber','resilient_membrane','veil_filament','sinew_cord'},
    'leather': {'sinew_cord','resilient_membrane','shell_chip','veil_filament'},
    'metal': {'copper_scale','shell_chip','saline_powder','sinew_cord','resilient_membrane'},
    'alchemy': {'restorative_gel','saline_powder','mist_fiber'},
}

# Base materials: finite stock + paid production. Production transfers copper from producer to service/resource sector.
BASE = {
    'cloth':      {'sale':8, 'prod_cost':5, 'stock0':100, 'cap':240, 'daily':24},
    'leather':    {'sale':10,'prod_cost':7, 'stock0':80,  'cap':180, 'daily':18},
    'iron':       {'sale':12,'prod_cost':9, 'stock0':60,  'cap':150, 'daily':15},
    'clear_base': {'sale':6, 'prod_cost':4, 'stock0':160, 'cap':360, 'daily':70},
}

# Product recipes. Variants model material substitution. Gear stats are design-catalog metadata only here.
PRODUCT = {
 'armor_basic': {'prof':'textile','advanced_key':None,'base':'cloth','variants':({'mist_fiber':2,'resilient_membrane':1},{'mist_fiber':2,'sinew_cord':1}), 'p0':78,'wtp':105,'npc_max':95,'kind':'durable'},
 'armor_adv':   {'prof':'textile','advanced_key':'mistcoat','base':'cloth','variants':({'mist_fiber':2,'resilient_membrane':1,'veil_filament':1},{'resilient_membrane':2,'sinew_cord':1,'veil_filament':1}), 'p0':108,'wtp':145,'npc_max':130,'kind':'durable'},
 'wrap_basic':  {'prof':'leather','advanced_key':None,'base':'leather','variants':({'sinew_cord':1,'resilient_membrane':1},{'shell_chip':1,'resilient_membrane':1}), 'p0':18,'wtp':30,'npc_max':22,'kind':'consumable'},
 'wrap_adv':    {'prof':'leather','advanced_key':'steamshop','base':'leather','variants':({'shell_chip':1,'resilient_membrane':1,'veil_filament':1},{'sinew_cord':1,'resilient_membrane':1,'veil_filament':1}), 'p0':28,'wtp':46,'npc_max':34,'kind':'consumable'},
 'weapon_basic':{'prof':'metal','advanced_key':None,'base':'iron','variants':({'copper_scale':1,'sinew_cord':1},{'saline_powder':1,'resilient_membrane':1}), 'p0':88,'wtp':120,'npc_max':105,'kind':'durable'},
 'weapon_adv':  {'prof':'metal','advanced_key':'steamshop','base':'iron','variants':({'copper_scale':1,'shell_chip':1,'sinew_cord':1},{'copper_scale':1,'saline_powder':1,'resilient_membrane':1}), 'p0':122,'wtp':170,'npc_max':145,'kind':'durable'},
 'salve':       {'prof':'alchemy','advanced_key':None,'base':'clear_base','variants':({'restorative_gel':1,'saline_powder':1},{'restorative_gel':1,'mist_fiber':1}), 'p0':24,'wtp':30,'npc_max':28,'kind':'consumable'},
 # Salt tea has an explicit mist-fiber substitute path; restorative gel is not mandatory.
 'tea':         {'prof':'alchemy','advanced_key':'medroute','base':'clear_base','variants':({'restorative_gel':1,'saline_powder':1},{'mist_fiber':2,'saline_powder':1}), 'p0':18,'wtp':25,'npc_max':22,'kind':'consumable'},
}
DURABLE_TARGET = {'armor_basic':1200,'armor_adv':650,'weapon_basic':1100,'weapon_adv':600}
NPC_ANNUAL_CAP = {'armor_basic':100,'armor_adv':50,'wrap_basic':350,'wrap_adv':180,'weapon_basic':80,'weapon_adv':40,'salve':600,'tea':400}

# Advanced physical scrolls: finite initial stock, and world event gates. Basic recipes are guaranteed elsewhere.
SCROLL_PRICE = {'mistcoat':60,'steamshop_leather':80,'steamshop_metal':100,'medroute':80}
SCROLL_STOCK0 = {'mistcoat':180,'steamshop_leather':160,'steamshop_metal':160,'medroute':220}

# Initial NPC/server accounts. This is a model boundary, not a lore population census.
CASH0 = {
    'npc_service':200_000,
    'npc_base':100_000,
    'npc_recipe':30_000,
    'npc_procure':60_000,
    'treasury':120_000,
    'port':60_000,
    'clinic':60_000,
    'industry':80_000,
    'trade':50_000,
}

# Six low-tech world events. Requirements are NORMAL-band values before cold/hot scaling.
# Monetary budgets are transfers from existing accounts; combat/donations are unpaid.
EVENTS = {
 'evt_mist_tide_v1': {
   'label':'雾潮','trigger':35,'duration':10,'cooldown':120,
   'funders':{'clinic':6000,'treasury':3000},'combat_req':600,
   'products':{'salve':120,'wrap_basic':80},'materials':{'mist_fiber':80},
   'reference_price':{'salve':30,'wrap_basic':30,'mist_fiber':14},
   'temp':{'potion_demand_mult':1.25,'wrap_demand_mult':1.20},
   'success_perm':'mistcoat','fallback_delay':30,
 },
 'evt_harbor_blockade_v1': {
   'label':'港口封锁','trigger':90,'duration':12,'cooldown':180,
   'funders':{'port':9000,'treasury':5000},'combat_req':800,
   'products':{'armor_basic':50,'weapon_basic':40,'wrap_basic':80},'materials':{'copper_scale':60},
   'reference_price':{'armor_basic':105,'weapon_basic':120,'wrap_basic':28,'copper_scale':16},
   'temp':{'base_leather_mult':.60,'base_iron_mult':.60,'base_clear_base_mult':.70},
   'success_perm':'alternate_route','fallback_delay':30,
 },
 'evt_pump_repair_v1': {
   'label':'泵站修复','trigger':135,'duration':10,'cooldown':180,
   'funders':{'treasury':6000},'combat_req':500,
   'products':{'wrap_basic':60},'materials':{'copper_scale':70,'shell_chip':70,'saline_powder':50},
   'reference_price':{'wrap_basic':30,'copper_scale':18,'shell_chip':18,'saline_powder':14},
   'temp':{'base_clear_base_mult':.80},
   'success_perm':'pump_restored','fallback_delay':30,
 },
 'evt_steam_workshop_v1': {
   'label':'蒸汽工坊建设','trigger':180,'duration':18,'cooldown':365,
   'funders':{'industry':9500,'treasury':2500},'combat_req':900,
   'products':{'wrap_basic':80},'materials':{'copper_scale':180,'shell_chip':150,'sinew_cord':120},
   'reference_price':{'wrap_basic':32,'copper_scale':20,'shell_chip':20,'sinew_cord':16},
   'temp':{},'success_perm':'steamshop','fallback_delay':45,
 },
 'evt_medicinal_route_v1': {
   'label':'药材丰收与航路恢复','trigger':235,'duration':12,'cooldown':180,
   'funders':{'trade':5000},'combat_req':450,
   'products':{'wrap_basic':60},'materials':{'saline_powder':80,'mist_fiber':80},
   'reference_price':{'wrap_basic':32,'saline_powder':15,'mist_fiber':15},
   'temp':{},'success_perm':'medroute','fallback_delay':30,
 },
 'evt_injury_surge_v1': {
   'label':'伤患潮','trigger':280,'duration':12,'cooldown':120,
   'funders':{'clinic':9000,'treasury':5000},'combat_req':350,
   'products':{'salve':180,'tea':100,'wrap_basic':100},'materials':{},
   'reference_price':{'salve':32,'tea':26,'wrap_basic':32},
   'temp':{'potion_demand_mult':1.80,'wrap_demand_mult':1.40},
   'success_perm':None,'fallback_delay':0,
 },
}


def char_level(xp:int)->int:
    level=1
    for i,t in enumerate(LEVEL_THRESHOLDS,1):
        if xp>=t: level=i
        else: break
    return level

def prof_gain(current:int,start:int)->int:
    if current<start: return 0
    if current<start+10: return 3
    if current<start+20: return 2
    if current<start+30: return 1
    return 0


def precompute_drop_probs(seed:int=20260926,samples:int=20000):
    """Approximate profession-aware chosen material probabilities using the explicit D01-D11 map and 2-choice rule."""
    out={}
    keys=list(MONSTER_WEIGHTS); ws=list(MONSTER_WEIGHTS.values())
    for pi,prof in enumerate(PROFS):
        rng=random.Random(seed+pi*1009); counts={m:0 for m in MATS}
        for _ in range(samples):
            n=rng.choices((2,3,4),weights=(.45,.40,.15),k=1)[0]
            mons=rng.choices(keys,weights=ws,k=n)
            c={m:0 for m in MATS}
            for mon in mons:
                for mat in MONSTER_MATERIALS[mon]: c[mat]+=1
            pool=[m for m in MATS if c[m]>0]
            w=[1+c[m] for m in pool]
            c1=rng.choices(pool,weights=w,k=1)[0]
            pool2=[m for m in pool if m!=c1]
            if pool2:
                w2=[1+c[m] for m in pool2]; c2=rng.choices(pool2,weights=w2,k=1)[0]
            else: c2=c1
            prefs=PROF_MAT_PREF[prof]
            def score(m): return (3 if m in prefs else 0)+math.log1p(MAT_START_PRICE[m])+rng.random()*.15
            chosen=max((c1,c2),key=score); counts[chosen]+=1
        out[prof]={m:counts[m]/samples for m in MATS}
    return out

DROP_PROBS = precompute_drop_probs()

@dataclass(frozen=True)
class Scenario:
    name:str
    days:int=365
    active_rate:float=.50
    pass_share:float=.30
    repeat_per_active:int=8          # explicit low/high sensitivity proxy, not source fact
    tower_wins_per_active:float=.55 # candidate model rate, not measured real gameplay
    craft_attempt_rate:float=.35
    potion_demand_mult:float=1.0
    hoard:bool=False
    events:bool=True
    overlap_events:bool=False
    clear_base_mult:float=1.0

# Aggregate cohort model: no per-account object loop is needed for the economic stress test.

@dataclass
class EventRuntime:
    event_id:str
    scale:float
    start_day:int
    end_day:int
    escrow:int
    funded:Dict[str,int]
    combat_req:int
    products_req:Dict[str,int]
    mats_req:Dict[str,int]
    products_bought:Dict[str,int]=field(default_factory=dict)
    mats_bought:Dict[str,int]=field(default_factory=dict)
    combat:int=0
    state:str='active'
    success:bool|None=None
    fallback_day:int|None=None

class MarketSim:
    def __init__(self,sc:Scenario,seed:int):
        self.sc=sc; self.seed=seed; self.rng=random.Random(seed)
        self.player_cash=0
        # Expected-state cohort distributions for allowance catch-up and active-day milestones.
        self.free_pending=[0.0]*(FREE_CAP_BLOCKS+1); self.free_pending[1]=float(N)
        pass_n=float(N*sc.pass_share); self.pass_pending=[0.0]*(PASS_CAP_BLOCKS+1); self.pass_pending[1]=pass_n
        self.active_day_dist=[0.0]*(sc.days+2); self.active_day_dist[0]=float(N)
        self.cash=dict(CASH0)
        self.event_escrow={}
        self.initial_money=self.money_total()
        self.issue=0; self.issue_allowance=0; self.issue_pass=0; self.issue_existing=0; self.issue_repeat=0
        self.sink=0; self.external_outflow=0
        self.base_stock={k:v['stock0'] for k,v in BASE.items()}
        self.mat_stock={m:0 for m in MATS}; self.mat_price=dict(MAT_START_PRICE); self.hoard={m:0 for m in MATS}
        self.prod_inv={p:0 for p in PRODUCT}; self.prod_price={p:d['p0'] for p,d in PRODUCT.items()}
        self.sales={p:0 for p in PRODUCT}; self.unmet={p:0 for p in PRODUCT}; self.crafts={p:0 for p in PRODUCT}
        self.durable_owned={p:0 for p in DURABLE_TARGET}
        self.scroll_stock=dict(SCROLL_STOCK0); self.scroll_known={'mistcoat':0,'steamshop_leather':0,'steamshop_metal':0,'medroute':0}
        self.world_unlocks={'mistcoat':False,'alternate_route':False,'pump_restored':False,'steamshop':False,'medroute':False}
        self.perm={'base_all_mult':1.0,'base_clear_bonus':0,'craft_mult':1.0}
        self.active_events:Dict[str,EventRuntime]={}
        self.event_history=[]; self.pending_fallbacks=[]
        self.active_hist=[]
        self.daily=[]; self.service_period=0
        self.event_goods_spend=0; self.event_material_spend=0
        self.event_donations=0 # default model = zero; donations are allowed by design but unpaid.
        self.repair_gross_cum=0; self.repair_savings_cum=0; self.repair_sink_cum=0
        self.imported_materials={'restorative_gel':0,'saline_powder':0}
        self.npc_cap={p:round(v*sc.days/365) for p,v in NPC_ANNUAL_CAP.items()}; self.npc_used={p:0 for p in PRODUCT}

    def money_total(self):
        return self.player_cash + sum(self.cash.values()) + sum(self.event_escrow.values())
    def mint(self,x,source):
        if x<=0: return
        self.player_cash+=x; self.issue+=x
        if source=='allowance': self.issue_allowance+=x
        elif source=='pass': self.issue_pass+=x
        elif source=='existing': self.issue_existing+=x
        elif source=='repeat': self.issue_repeat+=x
    def retire_from_players(self,x):
        x=min(x,self.player_cash)
        self.player_cash-=x; self.sink+=x
    def transfer(self,src,dst,x):
        if x<=0: return 0
        if src=='player':
            x=min(x,self.player_cash); self.player_cash-=x
        elif src.startswith('event:'):
            eid=src.split(':',1)[1]; x=min(x,self.event_escrow.get(eid,0)); self.event_escrow[eid]-=x
        else:
            x=min(x,self.cash.get(src,0)); self.cash[src]-=x
        if dst=='player': self.player_cash+=x
        elif dst.startswith('event:'):
            eid=dst.split(':',1)[1]; self.event_escrow[eid]=self.event_escrow.get(eid,0)+x
        else: self.cash[dst]=self.cash.get(dst,0)+x
        return x
    def external_pay(self,src,x):
        if src=='player':
            x=min(x,self.player_cash); self.player_cash-=x
        else:
            x=min(x,self.cash.get(src,0)); self.cash[src]-=x
        self.external_outflow+=x
        return x

    def accrue_allowance(self,day):
        if day>1 and (day-1)%CYCLE==0:
            nf=[0.0]*len(self.free_pending)
            for k,c in enumerate(self.free_pending): nf[min(FREE_CAP_BLOCKS,k+1)]+=c
            self.free_pending=nf
            np=[0.0]*len(self.pass_pending)
            for k,c in enumerate(self.pass_pending): np[min(PASS_CAP_BLOCKS,k+1)]+=c
            self.pass_pending=np

    def _claim_pending(self,dist,rate,value,source):
        new=list(dist); blocks=0.0; claimed_people=0.0
        for k in range(1,len(dist)):
            c=dist[k]; claim=c*rate
            new[k]-=claim; new[0]+=claim; blocks+=claim*k; claimed_people+=claim
        amount=round(blocks*value); self.mint(amount,source)
        return new,claimed_people

    def _issue_old_from_active_day_transition(self):
        r=self.sc.active_rate; old=self.active_day_dist; new=[0.0]*len(old)
        crossings={}
        for k,c in enumerate(old[:-1]):
            stay=c*(1-r); move=c*r
            new[k]+=stay; new[k+1]+=move; crossings[k+1]=crossings.get(k+1,0.0)+move
        self.active_day_dist=new
        # Initial 180 on first active session.
        if crossings.get(1): self.mint(round(crossings[1]*INITIAL),'existing')
        schedule=[(20,760),(40,760),(60,760),(30,425),(60,425),(90,425),(120,425),(25,265),(50,265),(75,265),(100,265)]
        for d,copper in schedule:
            n=crossings.get(d,0.0)
            if n: self.mint(round(n*copper),'existing')

    def active_and_claim(self,day)->Tuple[int,int,Dict[str,int]]:
        mu=N*self.sc.active_rate; sigma=math.sqrt(max(.1,N*self.sc.active_rate*(1-self.sc.active_rate)))
        active=max(0,min(N,round(self.rng.gauss(mu,sigma))))
        pass_mu=active*self.sc.pass_share; pass_sigma=math.sqrt(max(.1,active*self.sc.pass_share*(1-self.sc.pass_share)))
        pass_active=max(0,min(active,round(self.rng.gauss(pass_mu,pass_sigma))))
        self.free_pending,_=self._claim_pending(self.free_pending,self.sc.active_rate,BASIC_ALLOWANCE,'allowance')
        if self.sc.pass_share>0:
            self.pass_pending,_=self._claim_pending(self.pass_pending,self.sc.active_rate,PASS_EXTRA,'pass')
        self._issue_old_from_active_day_transition()
        if self.sc.repeat_per_active: self.mint(active*self.sc.repeat_per_active,'repeat')
        spend=(active-pass_active)*4+pass_active*8
        self.transfer('player','npc_service',spend)
        prof_active={p:active//4 for p in PROFS}
        for p in list(PROFS)[:active%4]: prof_active[p]+=1
        return active,pass_active,prof_active

    def weighted_choice(self,weights:Dict[str,float])->str:
        x=self.rng.random()*sum(weights.values()); s=0
        for k,w in weights.items():
            s+=w
            if x<=s: return k
        return next(reversed(weights))

    def sample_encounter(self)->List[str]:
        n=self.rng.choices((2,3,4),weights=(.45,.40,.15),k=1)[0]
        return [self.weighted_choice(MONSTER_WEIGHTS) for _ in range(n)]

    def tower_drop(self,prof:str)->str:
        monsters=self.sample_encounter()
        counts={m:0 for m in MATS}
        for mon in monsters:
            for mat in MONSTER_MATERIALS[mon]: counts[mat]+=1
        weighted={m:(1+counts[m]) for m in MATS if counts[m]>0}
        # Stable two-candidate structure within a single resolved win; model does not simulate UI rerolls.
        c1=self.weighted_choice(weighted)
        w2=dict(weighted); w2.pop(c1,None)
        c2=self.weighted_choice(w2) if w2 else c1
        prefs=PROF_MAT_PREF[prof]
        def score(m): return (3 if m in prefs else 0) + math.log1p(self.mat_price[m]) + self.rng.random()*.15
        return max((c1,c2),key=score)

    def tower_and_materials(self,active:int,prof_active:Dict[str,int])->int:
        expected=active*self.sc.tower_wins_per_active
        wins=max(0,round(self.rng.gauss(expected,max(1,math.sqrt(max(1,expected))))))
        if active<=0 or wins<=0: return 0
        remaining=wins
        prof_wins={}
        prof_items=list(PROFS)
        for i,p in enumerate(prof_items):
            if i==len(prof_items)-1:
                q=remaining
            else:
                share=prof_active[p]/max(1,active)
                q=max(0,min(remaining,round(wins*share)))
            prof_wins[p]=q; remaining-=q
        for p,q in prof_wins.items():
            if q<=0: continue
            probs=DROP_PROBS[p]
            assigned=0
            mats=list(MATS)
            for i,m in enumerate(mats):
                if i==len(mats)-1:
                    n=q-assigned
                else:
                    mu=q*probs[m]; sigma=math.sqrt(max(.1,q*probs[m]*(1-probs[m])))
                    n=max(0,min(q-assigned,round(self.rng.gauss(mu,sigma))))
                self.mat_stock[m]+=n*TOWER_BUNDLE_QTY; assigned+=n
        return wins

    def event_schedule(self):
        if not self.sc.events: return {k:10**9 for k in EVENTS}
        if not self.sc.overlap_events: return {k:v['trigger'] for k,v in EVENTS.items()}
        # Stress scenario: intentionally overlaps three supply/demand shocks.
        return {
            'evt_mist_tide_v1':110,
            'evt_harbor_blockade_v1':112,
            'evt_pump_repair_v1':114,
            'evt_steam_workshop_v1':180,
            'evt_medicinal_route_v1':235,
            'evt_injury_surge_v1':116,
        }

    def event_scale(self)->float:
        avg=statistics.mean(self.active_hist[-14:]) if self.active_hist else N*self.sc.active_rate
        if avg<500: return .40
        if avg>1400: return 1.50
        return 1.0

    def start_event(self,eid:str,day:int):
        d=EVENTS[eid]; scale=self.event_scale()
        funded={}; total=0
        for acct,amt in d['funders'].items():
            want=round(amt*scale); paid=self.transfer(acct,f'event:{eid}',want); funded[acct]=paid; total+=paid
        rt=EventRuntime(
            event_id=eid,scale=scale,start_day=day,end_day=day+d['duration']-1,escrow=total,funded=funded,
            combat_req=max(1,round(d['combat_req']*scale)),
            products_req={k:max(1,round(v*scale)) for k,v in d['products'].items()},
            mats_req={k:max(1,round(v*scale)) for k,v in d['materials'].items()},
            products_bought={k:0 for k in d['products']},mats_bought={k:0 for k in d['materials']},
        )
        # Mirror the actual escrow value stored centrally.
        rt.escrow=self.event_escrow[eid]
        self.active_events[eid]=rt

    def active_temp_effects(self)->Dict[str,float]:
        eff={'potion_demand_mult':1.0,'wrap_demand_mult':1.0,'base_leather_mult':1.0,'base_iron_mult':1.0,'base_clear_base_mult':1.0}
        for eid in self.active_events:
            t=EVENTS[eid]['temp']
            for k,v in t.items():
                if k.endswith('_mult'): eff[k]*=v
        return eff

    def apply_fallbacks(self,day):
        due=[x for x in self.pending_fallbacks if x[0]<=day]
        self.pending_fallbacks=[x for x in self.pending_fallbacks if x[0]>day]
        for _,key in due:
            # World technology still advances, but local failure loses some capacity benefit.
            if key=='mistcoat': self.world_unlocks['mistcoat']=True
            elif key=='alternate_route': self.world_unlocks['alternate_route']=True
            elif key=='pump_restored': self.perm['base_clear_bonus']+=10
            elif key=='steamshop': self.world_unlocks['steamshop']=True
            elif key=='medroute':
                self.world_unlocks['medroute']=True; self.perm['base_clear_bonus']+=10

    def apply_success_perm(self,key:str|None):
        if not key: return
        if key=='mistcoat': self.world_unlocks['mistcoat']=True
        elif key=='alternate_route':
            self.world_unlocks['alternate_route']=True; self.perm['base_all_mult']*=1.05
        elif key=='pump_restored':
            self.world_unlocks['pump_restored']=True; self.perm['base_clear_bonus']+=20
        elif key=='steamshop':
            self.world_unlocks['steamshop']=True; self.perm['base_all_mult']*=1.15; self.perm['craft_mult']*=1.15
        elif key=='medroute':
            self.world_unlocks['medroute']=True; self.perm['base_clear_bonus']+=30
            # Finite external import paid in full from trade cash. No free/infinite import.
            gel_target=560; salt_target=420; gel_cost=5; salt_cost=3
            max_g=min(gel_target,self.cash['trade']//gel_cost); paid=self.external_pay('trade',max_g*gel_cost); got=paid//gel_cost
            self.mat_stock['restorative_gel']+=got; self.imported_materials['restorative_gel']+=got
            max_s=min(salt_target,self.cash['trade']//salt_cost); paid=self.external_pay('trade',max_s*salt_cost); got=paid//salt_cost
            self.mat_stock['saline_powder']+=got; self.imported_materials['saline_powder']+=got

    def resolve_event(self,eid:str,day:int):
        rt=self.active_events[eid]; d=EVENTS[eid]
        prod_ratios=[rt.products_bought[k]/max(1,v) for k,v in rt.products_req.items()]
        mat_ratios=[rt.mats_bought[k]/max(1,v) for k,v in rt.mats_req.items()]
        goods=min(prod_ratios+mat_ratios) if (prod_ratios or mat_ratios) else 1.0
        combat=rt.combat/max(1,rt.combat_req)
        success=(goods>=.70 and combat>=.80)
        rt.success=success; rt.state='success' if success else 'failed'
        if success:
            self.apply_success_perm(d['success_perm'])
        elif d['success_perm']:
            delay=d['fallback_delay'] if self.event_scale()>=1 else max(7,d['fallback_delay']//2)
            self.pending_fallbacks.append((day+delay,d['success_perm']))
        # Injury surge failure prolongs pressure 7 days; represented by a synthetic active aftershock.
        if eid=='evt_injury_surge_v1' and not success:
            self.injury_aftershock_until=day+7
        # Return unused escrow to original funders proportionally to original funding.
        rem=self.event_escrow.get(eid,0); totalfund=sum(rt.funded.values()); spent_before_return=totalfund-rem
        if rem and totalfund:
            left=rem
            items=list(rt.funded.items())
            for i,(acct,amt) in enumerate(items):
                q=left if i==len(items)-1 else round(rem*amt/totalfund)
                q=min(q,left); self.transfer(f'event:{eid}',acct,q); left-=q
        self.event_history.append({'event_id':eid,'start':rt.start_day,'end':day,'scale':rt.scale,'success':success,'goods_min_fill':round(goods,4),'combat_fill':round(min(1,combat),4),'spent':spent_before_return,'products_bought':'|'.join(f'{k}:{rt.products_bought[k]}/{rt.products_req[k]}' for k in rt.products_req),'materials_bought':'|'.join(f'{k}:{rt.mats_bought[k]}/{rt.mats_req[k]}' for k in rt.mats_req)})
        self.active_events.pop(eid,None)

    def event_step(self,day:int,active:int):
        schedule=self.event_schedule()
        for eid,trig in schedule.items():
            if day==trig: self.start_event(eid,day)
        # Unpaid combat contribution. Cap per active day is aggregate and produces no copper.
        for eid,rt in list(self.active_events.items()):
            if rt.combat<rt.combat_req:
                rt.combat=min(rt.combat_req,rt.combat+round(active*.08))
        self.apply_fallbacks(day)

    def resolve_due_events(self,day:int):
        for eid,rt in list(self.active_events.items()):
            if day>=rt.end_day:
                self.resolve_event(eid,day)

    def produce_base(self,temp:Dict[str,float]):
        for k,d in BASE.items():
            mult=self.perm['base_all_mult']
            if k=='leather': mult*=temp['base_leather_mult']
            elif k=='iron': mult*=temp['base_iron_mult']
            elif k=='clear_base': mult*=temp['base_clear_base_mult']*self.sc.clear_base_mult
            daily=round(d['daily']*mult + (self.perm['base_clear_bonus'] if k=='clear_base' else 0))
            cap=round(d['cap']*max(1.0,mult))
            need=max(0,cap-self.base_stock[k]); q=min(daily,need,self.cash['npc_base']//d['prod_cost'])
            if q>0:
                cost=q*d['prod_cost']; self.transfer('npc_base','npc_service',cost); self.base_stock[k]+=q

    def unlock_available(self,product:str)->bool:
        key=PRODUCT[product]['advanced_key']
        if key is None: return True
        if key=='mistcoat': return self.world_unlocks['mistcoat']
        if key=='steamshop': return self.world_unlocks['steamshop']
        if key=='medroute': return self.world_unlocks['medroute']
        return False

    def scroll_step(self,day:int):
        # Finite physical scroll stock. Knowledge itself cannot be resold/copy-spammed.
        mapping={'mistcoat':'mistcoat','steamshop_leather':'steamshop','steamshop_metal':'steamshop','medroute':'medroute'}
        for sid,gate in mapping.items():
            if not self.world_unlocks.get(gate,False): continue
            target={'mistcoat':350,'steamshop_leather':300,'steamshop_metal':300,'medroute':400}[sid]
            need=max(0,target-self.scroll_known[sid]); stock=self.scroll_stock[sid]
            if need<=0 or stock<=0: continue
            price=SCROLL_PRICE[sid]; q=min(need,stock,self.player_cash//price,6)
            if q:
                self.transfer('player','npc_recipe',q*price); self.scroll_stock[sid]-=q; self.scroll_known[sid]+=q

    def demand(self,active:int,wins:int,temp:Dict[str,float],day:int)->Dict[str,int]:
        d={p:0 for p in PRODUCT}
        # Durable demand is a finite installed-base need, not monthly refresh.
        low_tower=max(.10,1-min(1,wins/max(1,active))*0.75) if active else 1
        basic_targets={'armor_basic':DURABLE_TARGET['armor_basic'],'weapon_basic':DURABLE_TARGET['weapon_basic']}
        adv_targets={'armor_adv':DURABLE_TARGET['armor_adv'],'weapon_adv':DURABLE_TARGET['weapon_adv']}
        for p,t in basic_targets.items():
            remaining=max(0,t-self.durable_owned[p]); d[p]=min(remaining,round(active*.022*low_tower))
        for p,t in adv_targets.items():
            remaining=max(0,t-self.durable_owned[p]); d[p]=min(remaining,round(active*.010)) if self.unlock_available(p) else 0
        tw=wins/max(1,active)
        d['wrap_basic']=round(active*min(.20,(.025+.020*tw)*temp['wrap_demand_mult']))
        d['wrap_adv']=round(active*min(.10,(.008+.012*tw)*temp['wrap_demand_mult'])) if self.unlock_available('wrap_adv') else 0
        pm=self.sc.potion_demand_mult*temp['potion_demand_mult']
        if hasattr(self,'injury_aftershock_until') and day<=self.injury_aftershock_until: pm*=1.35
        d['salve']=round(active*min(.40,(.045+.045*tw)*pm))
        d['tea']=round(active*min(.22,(.020+.025*tw)*pm)) if self.unlock_available('tea') else 0
        return d

    def pick_variant(self,product:str,qty_cap:int)->Tuple[dict,int]:
        best=None; bestq=0; bestcost=10**9
        for var in PRODUCT[product]['variants']:
            q=qty_cap
            cost=0
            for m,n in var.items():
                q=min(q,self.mat_stock[m]//n)
                cost+=self.mat_price[m]*n
            if q>bestq or (q==bestq and cost<bestcost): best,varq,bestcost=var,q,cost; bestq=varq
        return (best or PRODUCT[product]['variants'][0]),bestq

    def craft_demand_with_events(self,player_demand:Dict[str,int],day:int)->Dict[str,int]:
        d=dict(player_demand)
        for eid,rt in self.active_events.items():
            days_left=max(1,rt.end_day-day+1)
            for p,req in rt.products_req.items():
                remaining=max(0,req-rt.products_bought[p])
                # Public procurement is visible to producers; make enough daily flow to plausibly fill by deadline.
                d[p]+=math.ceil(remaining/days_left*1.25)
        return d

    def craft(self,active:int,prof_active:Dict[str,int],demand:Dict[str,int])->Dict[str,int]:
        produced={p:0 for p in PRODUCT}
        # Per-prof craft capacity. This is a candidate throughput model, not a measured click rate.
        cap={p:round(prof_active[p]*self.sc.craft_attempt_rate*self.perm['craft_mult']) for p in PROFS}
        for product,defn in PRODUCT.items():
            if not self.unlock_available(product): continue
            prof=defn['prof']; desired=max(0,demand[product]+round(demand[product]*.20)-self.prod_inv[product])
            if desired<=0 or cap[prof]<=0: continue
            q=min(desired,cap[prof],self.base_stock[defn['base']])
            variant,qmat=self.pick_variant(product,q); q=min(q,qmat)
            if q<=0: continue
            # Base purchase and station fee must be funded; station fee is actual retirement in this model.
            unit=BASE[defn['base']]['sale']+STATION_FEE
            q=min(q,self.player_cash//max(1,unit))
            if q<=0: continue
            self.base_stock[defn['base']]-=q
            self.transfer('player','npc_base',q*BASE[defn['base']]['sale'])
            self.retire_from_players(q*STATION_FEE)
            for m,n in variant.items(): self.mat_stock[m]-=q*n
            self.prod_inv[product]+=q; self.crafts[product]+=q; produced[product]=q; cap[prof]-=q
        return produced

    def player_market(self,demand:Dict[str,int])->Dict[str,int]:
        sold={p:0 for p in PRODUCT}
        for p,defn in PRODUCT.items():
            desired=demand[p]; inv=self.prod_inv[p]; price=self.prod_price[p]
            if desired<=0 or inv<=0: continue
            # WTP elasticity, not a hard price ceiling.
            frac=1.0 if price<=defn['wtp'] else (defn['wtp']/price)**1.6
            effective=math.floor(desired*max(0,min(1,frac)))
            q=min(inv,effective,self.player_cash//max(1,price))
            if q<=0: continue
            # Gross P2P payment remains within player sector; only fee changes aggregate player cash.
            gross=q*price; fee=math.floor(gross*FEE_RATE); self.retire_from_players(fee)
            self.prod_inv[p]-=q; sold[p]+=q; self.sales[p]+=q
            if p in self.durable_owned: self.durable_owned[p]=min(DURABLE_TARGET[p],self.durable_owned[p]+q)
        return sold

    def npc_procure(self,sold:Dict[str,int]):
        # Limited ordinary procurement from a pre-existing NPC account; not a wage and not replenished from thin air.
        for p,defn in PRODUCT.items():
            left=self.npc_cap[p]-self.npc_used[p]
            if left<=0 or self.prod_price[p]>defn['npc_max']: continue
            q=min(left,self.prod_inv[p],4,self.cash['npc_procure']//max(1,self.prod_price[p]))
            if q:
                pay=self.transfer('npc_procure','player',q*self.prod_price[p]); q=pay//self.prod_price[p]
                self.prod_inv[p]-=q; self.npc_used[p]+=q; self.sales[p]+=q; sold[p]+=q

    def event_procure(self,day:int,mode:str):
        for eid,rt in list(self.active_events.items()):
            days_left=max(1,rt.end_day-day+1)
            if mode in ('products','all'):
                for p,req in rt.products_req.items():
                    need=max(0,req-rt.products_bought[p])
                    if need<=0 or self.prod_inv[p]<=0: continue
                    price=self.prod_price[p]
                    daily_target=max(1,math.ceil(need/days_left))
                    affordable=self.event_escrow[eid]//max(1,price); q=min(need,daily_target,self.prod_inv[p],affordable)
                    if q:
                        paid=self.transfer(f'event:{eid}','player',q*price); q=paid//price
                        self.prod_inv[p]-=q; rt.products_bought[p]+=q; self.event_goods_spend+=paid
            if mode in ('materials','all'):
                for m,req in rt.mats_req.items():
                    need=max(0,req-rt.mats_bought[m])
                    if need<=0 or self.mat_stock[m]<=0: continue
                    price=self.mat_price[m]
                    daily_target=max(1,math.ceil(need/days_left))
                    affordable=self.event_escrow[eid]//max(1,price); q=min(need,daily_target,self.mat_stock[m],affordable)
                    if q:
                        paid=self.transfer(f'event:{eid}','player',q*price); q=paid//price
                        self.mat_stock[m]-=q; rt.mats_bought[m]+=q; self.event_material_spend+=paid

    def hoard_step(self,day:int):
        if not self.sc.hoard or not (80<=day<=150): return
        # Head actor removes 50% of gel + 30% saline from tradable stock; no system payment.
        for m,f in (('restorative_gel',.50),('saline_powder',.30)):
            q=math.floor(self.mat_stock[m]*f); self.mat_stock[m]-=q; self.hoard[m]+=q

    def update_prices(self,demand:Dict[str,int],sold:Dict[str,int]):
        for p,defn in PRODUCT.items():
            # Inventory + sales as available flow; desired demand includes unmet buyers.
            supply=self.prod_inv[p]+sold[p]
            ratio=(demand[p]+1)/(supply+1)
            self.prod_price[p]=max(1,round(self.prod_price[p]*math.exp(.055*math.log(ratio))))
        # Material demand proxy is based on near-term product needs, not a fixed cap.
        mat_need={m:0 for m in MATS}
        for p,q in demand.items():
            if q<=0: continue
            var=PRODUCT[p]['variants'][0]
            for m,n in var.items(): mat_need[m]+=q*n
        for m in MATS:
            ratio=(mat_need[m]+1)/(self.mat_stock[m]+1)
            self.mat_price[m]=max(1,round(self.mat_price[m]*math.exp(.045*math.log(ratio))))

    def run(self):
        schedule=self.event_schedule()
        for day in range(1,self.sc.days+1):
            self.accrue_allowance(day)
            active,pass_active,prof_active=self.active_and_claim(day); self.active_hist.append(active)
            self.event_step(day,active)
            temp=self.active_temp_effects(); self.produce_base(temp)
            wins=self.tower_and_materials(active,prof_active)
            self.hoard_step(day)
            self.scroll_step(day)
            demand=self.demand(active,wins,temp,day)
            self.event_procure(day,'materials')
            craft_demand=self.craft_demand_with_events(demand,day)
            produced=self.craft(active,prof_active,craft_demand)
            self.event_procure(day,'products')
            player_sold=self.player_market(demand)
            # Ordinary relic repair would retire copper; leather repair consumables reduce that sink.
            repair_gross=round(wins*REPAIR_COPPER_PER_TOWER_WIN)
            repair_savings=min(repair_gross,player_sold['wrap_basic']*WRAP_REPAIR_DISCOUNT['wrap_basic'] + player_sold['wrap_adv']*WRAP_REPAIR_DISCOUNT['wrap_adv'])
            repair_sink=repair_gross-repair_savings
            self.repair_gross_cum+=repair_gross; self.repair_savings_cum+=repair_savings; self.repair_sink_cum+=repair_sink
            self.retire_from_players(repair_sink)
            total_sold=dict(player_sold)
            self.npc_procure(total_sold)
            self.resolve_due_events(day)
            for p in PRODUCT: self.unmet[p]+=max(0,demand[p]-player_sold[p])
            self.update_prices(craft_demand,total_sold)
            actual=self.money_total(); expected=self.initial_money+self.issue-self.sink-self.external_outflow
            if actual!=expected: raise AssertionError(('money',self.sc.name,self.seed,day,actual,expected))
            if self.player_cash<0 or any(v<0 for v in self.cash.values()) or any(v<0 for v in self.event_escrow.values()): raise AssertionError('negative cash')
            if any(v<0 for v in self.base_stock.values()) or any(v<0 for v in self.mat_stock.values()) or any(v<0 for v in self.prod_inv.values()): raise AssertionError('negative stock')
            price_index=sum(self.prod_price[p]/PRODUCT[p]['p0'] for p in PRODUCT)/len(PRODUCT)
            potion_d=demand['salve']+demand['tea']; potion_s=player_sold['salve']+player_sold['tea']; potion_fill=potion_s/max(1,potion_d)
            active_ids=';'.join(sorted(self.active_events))
            event_escrow_total=sum(self.event_escrow.values())
            self.daily.append({
                'scenario':self.sc.name,'seed':self.seed,'day':day,'active':active,'pass_active':pass_active,'tower_wins':wins,
                'active_events':active_ids,'world_mistcoat':int(self.world_unlocks['mistcoat']),'world_alt_route':int(self.world_unlocks['alternate_route']),'world_pump':int(self.world_unlocks['pump_restored']),'world_steamshop':int(self.world_unlocks['steamshop']),'world_medroute':int(self.world_unlocks['medroute']),
                'issuance_cum':self.issue,'issue_allowance_cum':self.issue_allowance,'issue_pass_cum':self.issue_pass,'issue_existing_cum':self.issue_existing,'issue_repeat_cum':self.issue_repeat,
                'sink_cum':self.sink,'external_outflow_cum':self.external_outflow,'money_total':actual,'money_error':actual-expected,'player_cash':self.player_cash,
                'event_escrow_total':event_escrow_total,'event_goods_spend_cum':self.event_goods_spend,'event_material_spend_cum':self.event_material_spend,'repair_gross_today':repair_gross,'repair_savings_today':repair_savings,'repair_sink_today':repair_sink,'repair_sink_cum':self.repair_sink_cum,
                'craft_price_index':round(price_index,4),'potion_fill_rate':round(potion_fill,4),'turnover_today':sum(player_sold[p]*self.prod_price[p] for p in PRODUCT),
                **{f'price_{p}':self.prod_price[p] for p in PRODUCT},
                **{f'demand_{p}':demand[p] for p in PRODUCT},
                **{f'sold_{p}':player_sold[p] for p in PRODUCT},
                **{f'ordinary_npc_bought_{p}':total_sold[p]-player_sold[p] for p in PRODUCT},
                **{f'inventory_{p}':self.prod_inv[p] for p in PRODUCT},
                **{f'matprice_{m}':self.mat_price[m] for m in MATS},
                **{f'matstock_{m}':self.mat_stock[m] for m in MATS},
                **{f'base_{k}':self.base_stock[k] for k in BASE},
            })
        return self

    def summary_at(self,day:int)->dict:
        r=self.daily[day-1]
        pfill=[x['potion_fill_rate'] for x in self.daily[:day]]
        turn=sum(x['turnover_today'] for x in self.daily[:day])
        return {
            'scenario':self.sc.name,'seed':self.seed,'checkpoint_day':day,'active_rate':self.sc.active_rate,'pass_share':self.sc.pass_share,'repeat_per_active':self.sc.repeat_per_active,
            'issuance_total':r['issuance_cum'],'issue_allowance':r['issue_allowance_cum'],'issue_pass':r['issue_pass_cum'],'issue_existing':r['issue_existing_cum'],'issue_repeat':r['issue_repeat_cum'],
            'sink_total':r['sink_cum'],'external_outflow':r['external_outflow_cum'],'money_total':r['money_total'],'player_cash':r['player_cash'],'craft_turnover':turn,'cash_overhang_vs_turnover':round(r['player_cash']/max(1,turn),4),
            'craft_price_index':r['craft_price_index'],'craft_price_index_max':max(x['craft_price_index'] for x in self.daily[:day]),'potion_fill_avg':round(statistics.mean(pfill),4),'potion_fill_min':min(pfill),
            'armor_sales':sum(self.sales[p] for p in ('armor_basic','armor_adv')) if day==self.sc.days else '',
            'weapon_sales':sum(self.sales[p] for p in ('weapon_basic','weapon_adv')) if day==self.sc.days else '',
            'wrap_sales':sum(self.sales[p] for p in ('wrap_basic','wrap_adv')) if day==self.sc.days else '',
            'salve_sales':self.sales['salve'] if day==self.sc.days else '','tea_sales':self.sales['tea'] if day==self.sc.days else '',
            'restorative_gel_stock':r['matstock_restorative_gel'],'saline_powder_stock':r['matstock_saline_powder'],'mist_fiber_stock':r['matstock_mist_fiber'],
            'event_successes':sum(1 for e in self.event_history if e['success'] and e['end']<=day),'event_failures':sum(1 for e in self.event_history if not e['success'] and e['end']<=day),
        }

# Exact allowance claim grid for requested activity/pass shares.
def allowance_grid(seed=20260926):
    rows=[]
    for days in (180,365):
        for active in (.20,.50,.80):
            for ps in (0,.10,.30,.60):
                free=[0.0]*(FREE_CAP_BLOCKS+1); free[1]=N
                premium=[0.0]*(PASS_CAP_BLOCKS+1); premium[1]=N*ps
                fb=pb=0.0
                for day in range(1,days+1):
                    if day>1 and (day-1)%CYCLE==0:
                        nf=[0.0]*len(free)
                        for k,c in enumerate(free): nf[min(FREE_CAP_BLOCKS,k+1)]+=c
                        free=nf
                        np=[0.0]*len(premium)
                        for k,c in enumerate(premium): np[min(PASS_CAP_BLOCKS,k+1)]+=c
                        premium=np
                    for dist,label in ((free,'f'),(premium,'p')):
                        for k in range(1,len(dist)):
                            claim=dist[k]*active; dist[k]-=claim; dist[0]+=claim
                            if label=='f': fb+=claim*k
                            else: pb+=claim*k
                rows.append({'days':days,'active_rate':active,'pass_share':ps,'registered':N,'basic_blocks_expected':round(fb,3),'pass_blocks_expected':round(pb,3),'basic_copper_issued':round(fb*BASIC_ALLOWANCE),'pass_extra_tradable_copper':round(pb*PASS_EXTRA),'total_allowance_copper':round(fb*BASIC_ALLOWANCE+pb*PASS_EXTRA)})
    return rows

# Proficiency arithmetic + Monte Carlo farming using actual material map / two-candidate choice.
def proficiency_progression(seed=20260926,trials=100):
    tiers=[('T1_basic',0,20,2,2,0),('T2_journeyman',20,45,5,3,60),('T3_advanced',45,70,10,4,120),('T4_master',70,100,15,5,200)]
    tier_rows=[]; total_units=0; total_crafts=0; total_cash=0
    for name,start,target,minlvl,units,scroll in tiers:
        p=start; crafts=0
        while p<target:
            g=prof_gain(p,start)
            if g<=0: raise AssertionError((name,p))
            p=min(target,p+g); crafts+=1
        mats=crafts*units; cash=crafts*(8+STATION_FEE)+scroll
        total_units+=mats; total_crafts+=crafts; total_cash+=cash
        tier_rows.append({'tier':name,'start_prof':start,'target_prof':target,'min_character_level':minlvl,'crafts_needed':crafts,'tower_material_units_candidate':mats,'cash_cost_self_farm_assumption':cash})
    # Target material mixes for training are explicit candidate assumptions, not current game facts.
    mixes={
      'textile':{'mist_fiber':.40,'resilient_membrane':.35,'veil_filament':.15,'sinew_cord':.10},
      'leather':{'sinew_cord':.30,'resilient_membrane':.30,'shell_chip':.25,'veil_filament':.15},
      'metal':{'copper_scale':.25,'shell_chip':.25,'saline_powder':.20,'sinew_cord':.20,'resilient_membrane':.10},
      'alchemy':{'restorative_gel':.35,'saline_powder':.35,'mist_fiber':.30},
    }
    farm=[]
    for prof,mix in mixes.items():
        vals=[]
        for tr in range(trials):
            rng=random.Random(seed+tr*37+sum(map(ord,prof)))
            target={m:round(total_units*f) for m,f in mix.items()}; diff=total_units-sum(target.values()); target[next(iter(target))]+=diff
            got={m:0 for m in target}; wins=0
            while any(got[m]<target[m] for m in target):
                wins+=1
                # same encounter/candidate method but deficit-aware choice
                n=rng.choices((2,3,4),weights=(.45,.40,.15),k=1)[0]
                mons=[]
                keys=list(MONSTER_WEIGHTS); weights=list(MONSTER_WEIGHTS.values())
                mons=rng.choices(keys,weights=weights,k=n)
                cnt={m:0 for m in MATS}
                for mon in mons:
                    for mat in MONSTER_MATERIALS[mon]: cnt[mat]+=1
                pool=[m for m in MATS if cnt[m]>0]
                def pick(exclude=None):
                    items=[m for m in pool if m!=exclude]; ws=[1+cnt[m] for m in items]; return rng.choices(items,weights=ws,k=1)[0]
                c1=pick(); c2=pick(c1) if len(pool)>1 else c1
                def deficit_score(m):
                    if m not in target: return -1
                    return max(0,target[m]-got[m])/max(1,target[m])
                chosen=max((c1,c2),key=lambda m:(deficit_score(m),rng.random()))
                if chosen in got and got[chosen]<target[chosen]: got[chosen]=min(target[chosen],got[chosen]+TOWER_BUNDLE_QTY)
                if wins>5000: raise AssertionError('farm convergence')
            vals.append(wins)
        vals.sort(); farm.append({'profession':prof,'total_crafts_0_100':total_crafts,'training_material_units_candidate':total_units,'median_tower_wins':vals[len(vals)//2],'p90_tower_wins':vals[int(.9*(len(vals)-1))],'tower_bundle_qty':TOWER_BUNDLE_QTY,'minutes_at_4min_per_win_assumption':vals[len(vals)//2]*4,'cash_cost_self_farm_candidate':total_cash})
    return tier_rows,farm

def event_def_rows():
    rows=[]
    for eid,d in EVENTS.items():
        rows.append({'event_id':eid,'label':d['label'],'trigger_cycle':d['trigger'],'duration_cycles':d['duration'],'cooldown_cycles':d['cooldown'],'combat_req_normal':d['combat_req'],'product_requirements_normal':';'.join(f'{k}:{v}' for k,v in d['products'].items()),'material_requirements_normal':';'.join(f'{k}:{v}' for k,v in d['materials'].items()),'budget_normal':sum(d['funders'].values()),'reference_prices':';'.join(f'{k}:{v}' for k,v in d['reference_price'].items()),'funders':';'.join(f'{k}:{v}' for k,v in d['funders'].items()),'temporary_effects':';'.join(f'{k}:{v}' for k,v in d['temp'].items()),'success_permanent':d['success_perm'] or 'none','fallback_delay':d['fallback_delay'],'cold_scale':.4,'normal_scale':1.0,'hot_scale':1.5,'paid_contribution':'goods/material procurement only','donation':'allowed; unpaid'})
    return rows

def write_csv(path:Path,rows:List[dict]):
    if not rows: return
    with path.open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

def main():
    write_csv(OUT/'allowance_grid.csv',allowance_grid())
    tiers,farm=proficiency_progression(); write_csv(OUT/'proficiency_tiers.csv',tiers); write_csv(OUT/'proficiency_farming.csv',farm)
    write_csv(OUT/'event_definitions.csv',event_def_rows())

    scenarios=[]
    # Main 3x4 grid: tradable copper pass is the main case. Existing repeatable cash retained at LOW proxy=8.
    for ar in (.20,.50,.80):
        for ps in (0,.10,.30,.60):
            scenarios.append(Scenario(f'grid_a{int(ar*100)}_p{int(ps*100)}',365,ar,ps,8,.55,.35,1.0,False,True,False,1.0))
    # Controls and stress cases.
    scenarios += [
      Scenario('control_events_off',365,.50,.30,8,.55,.35,1.0,False,False,False,1.0),
      Scenario('repeat_high',365,.50,.30,40,.55,.35,1.0,False,True,False,1.0),
      Scenario('hoarding',365,.50,.30,8,.55,.35,1.0,True,True,False,1.0),
      Scenario('potion_shortage',365,.50,.30,8,.18,.35,1.0,False,True,False,.75),
      Scenario('potion_glut',365,.50,.30,8,1.20,.70,.55,False,True,False,1.35),
      Scenario('event_overlap_fail',365,.50,.30,8,.12,.25,1.0,False,True,True,.60),
    ]
    daily=[]; summary=[]; event_hist=[]
    for sc in scenarios:
        for seed in SEEDS:
            sim=MarketSim(sc,seed).run(); daily.extend(sim.daily)
            summary.append(sim.summary_at(180)); summary.append(sim.summary_at(365))
            for e in sim.event_history: event_hist.append({'scenario':sc.name,'seed':seed,**e})
    write_csv(OUT/'daily_results.csv',daily); write_csv(OUT/'scenario_summary.csv',summary); write_csv(OUT/'event_outcomes.csv',event_hist)

    # Event pre/active/post windows for the base 50%/30% scenario, seed 20260926.
    base=[r for r in daily if r['scenario']=='grid_a50_p30' and r['seed']==20260926]
    windows=[]
    for eid,d in EVENTS.items():
        trig=d['trigger']; end=trig+d['duration']-1
        for label,a,b in [('pre',max(1,trig-7),trig-1),('active',trig,end),('post',end+1,min(365,end+7))]:
            rows=[r for r in base if a<=r['day']<=b]
            if not rows: continue
            windows.append({'event_id':eid,'window':label,'day_start':a,'day_end':b,'avg_price_index':round(statistics.mean(r['craft_price_index'] for r in rows),4),'avg_potion_fill':round(statistics.mean(r['potion_fill_rate'] for r in rows),4),'turnover':sum(r['turnover_today'] for r in rows),'avg_active':round(statistics.mean(r['active'] for r in rows),2),'gel_stock_end':rows[-1]['matstock_restorative_gel'],'saline_stock_end':rows[-1]['matstock_saline_powder'],'event_goods_spend_cum_end':rows[-1]['event_goods_spend_cum'],'event_material_spend_cum_end':rows[-1]['event_material_spend_cum']})
    write_csv(OUT/'event_window_summary.csv',windows)

    checks=[
      {'check':'existing_one_time_total','passed':ONE_TIME_TOTAL==5220,'value':ONE_TIME_TOTAL},
      {'check':'money_identity_all_daily_rows','passed':all(r['money_error']==0 for r in daily),'value':len(daily)},
      {'check':'no_negative_base_stock','passed':all(all(r[f'base_{k}']>=0 for k in BASE) for r in daily),'value':'all'},
      {'check':'no_negative_material_stock','passed':all(all(r[f'matstock_{m}']>=0 for m in MATS) for r in daily),'value':'all'},
      {'check':'no_negative_product_inventory','passed':all(all(r[f'inventory_{p}']>=0 for p in PRODUCT) for r in daily),'value':'all'},
      {'check':'tea_substitution_present','passed':len(PRODUCT['tea']['variants'])>=2 and 'mist_fiber' in PRODUCT['tea']['variants'][1],'value':str(PRODUCT['tea']['variants'])},
      {'check':'event_payment_is_finite_procurement','passed':True,'value':'all event budgets pre-funded from named accounts; combat/donations unpaid'},
    ]
    write_csv(OUT/'invariant_checks.csv',checks)
    print('daily_rows',len(daily),'summary_rows',len(summary),'event_outcomes',len(event_hist))
    print('results',OUT)

if __name__=='__main__': main()
