"""Independent-account economy experiment; candidate rules, not game runtime.
Integer copper, finite inventories, actual counterparties and trade-time gross.
One simulated day is an experimental cycle, not a paid entitlement promise.
"""
from dataclasses import dataclass, field, asdict
from collections import defaultdict
from bisect import bisect_right
import json, math, random, statistics
from pathlib import Path

SOURCE=json.loads(Path(__file__).with_name('source_inputs.json').read_text())
MATS=('mist_fiber','membrane','shell','sinew','salt','gel','filament','copper')
PROFS=('textile','leather','metal','alchemy')
MAP={'D01':(2,3),'D02':(4,1),'D03':(1,5),'D04':(2,3),'D05':(0,6),'D06':(3,7),'D07':(2,7),'D08':(2,3),'D09':(0,6),'D10':(1,5,4),'D11':(4,0)}
XP=(0,100,220,360,520,700,900,1120,1360,1620,1900,2200,2520,2860,3220,3600,4000,4420,5000,6000)
STAGES=(0,20,45,70); LEVELS=(2,5,10,15)
# Intermediate tier recipes are explicitly new experimental placeholders.
# Materials + one base per batch; all outputs have a use, durable demand is finite.
RECIPES=[]
for prof,mats in enumerate(({0:2,1:1},{3:1,1:1},{7:1,3:1},{5:1,4:1})):
    for tier in range(4):
        req=dict(mats)
        if tier>=2: req[6 if prof<3 else 0]=1
        if tier==3: req[2 if prof<3 else 4]=req.get(2 if prof<3 else 4,0)+1
        req[8+prof]=1
        RECIPES.append(req)
P0=[6,8,10,7,6,10,12,10,8,10,12,6]+[v for base in (78,18,88,24) for v in (base,round(base*1.2),round(base*1.4),round(base*1.65))]
ITEMS=MATS+('cloth','leather','iron','clear_base')+tuple(f'{p}_t{t}' for p in PROFS for t in range(4))

@dataclass(frozen=True)
class Config:
    name:str='baseline'
    n:int=2000
    days:int=730
    activity:float=.5
    pass_share:float=.3
    allowance:int=28
    pass_extra:int=28
    bundle:int=2
    base_capacity:float=1.
    fee_bps:int=500
    crafting:float=.45
    tower_rate:float=.65
    repeat_rate:float=.25
    repeat_strategy:str='uniform'
    drug_need:float=.18
    demand_elasticity:float=.15
    event_mode:str='two'
    veterans:float=.2
    newcomers:float=.1
    churn:float=0.
    hoard:bool=False
    dump:bool=False
    shortage:bool=False
    price_response:float=.025

@dataclass
class Player:
    prof:int
    paid:bool
    activity:float
    join:int
    cash:int=180
    inv:list=field(default_factory=lambda:[0]*28)
    q:int=0
    floor:int=0
    bounty:set=field(default_factory=set)
    xp:int=0
    skill:int=0
    learned:set=field(default_factory=lambda:{0})
    gear:list=field(default_factory=lambda:[-1,-1])
    durability:int=100
    value:int=120
    need:int=0
    active_days:int=0
    sales:int=0
    costs:int=0
    crafts:int=0
    battles:int=0

class Sim:
    def __init__(self,c,seed,trace=False):
        self.c=c;self.r=random.Random(seed);self.seed=seed;self.trace=trace
        self.p=[]
        for i in range(c.n):
            prof=i%4; paid=self.r.random()<c.pass_share
            join=self.r.randint(1,max(1,c.days//2)) if self.r.random()<c.newcomers else 0
            a=Player(prof,paid,min(.99,c.activity*self.r.uniform(.35,1.65)),join)
            if join==0 and self.r.random()<c.veterans:
                a.q=30;a.floor=100;a.xp=6000;a.bounty=set(range(10));a.skill=45;a.learned={0,1,2};a.gear=[1,1]
                a.cash=int(self.r.lognormvariate(7.1,1.15));a.value=400
            self.p.append(a)
        # Account IDs n: base merchant; n+1: resource/service; n+2: treasury;
        # n+3: escrow; n+4: recipe vendor. All balances stay in the identity.
        self.npc=[100000,200000,120000,0,30000]
        self.base=[100,80,60,160];self.open_money=self.total_money()
        self.issue=defaultdict(int);self.sinks=defaultdict(int)
        self.created=[0]*28;self.used=[0]*28
        for j,v in enumerate(self.base):self.created[8+j]=v
        self.ref=[float(x) for x in P0]
        self.last_trade=[None]*28;self.trade_today=[[] for _ in ITEMS]
        self.gross=0;self.trades=0;self.trade_examples=[];self.days=[]
        self.event=None;self.events=[];self.pump=False;self.mist=False
        self.d30=[a.cash for a in self.p];self.d30_delta=[]
        self.recipe_stock=[[c.n]*4 for _ in range(4)]
        self.cohort=defaultdict(lambda:[0,0,0,0]);self.wealth_flows=defaultdict(int);self.wealth_group={i:'unranked' for i in range(c.n)}
        self.cash_blocked=0;self.total_drug_need=0;self.total_drug_met=0
        self.material_requests=0;self.material_filled=0
        self.initial_wallet=[a.cash for a in self.p]
        self.fee_remainder=0

    def total_money(self):return sum(a.cash for a in self.p)+sum(self.npc)
    def issue_to(self,a,amount,reason):a.cash+=amount;self.issue[reason]+=amount
    def retire(self,a,amount,reason):
        assert 0<=amount<=a.cash
        a.cash-=amount;self.sinks[reason]+=amount
    def pay_npc(self,a,amount,account):
        if a.cash<amount:return False
        a.cash-=amount;self.npc[account]+=amount;return True

    def transfer_good(self,buyer,seller,item,qty,price):
        """Both parties checked; no shared player wallet. Gross captured NOW."""
        if buyer==seller or qty<=0 or price<=0:return False
        a=self.p[buyer] if buyer<self.c.n else None
        b=self.p[seller] if seller<self.c.n else None
        cash=a.cash if a else self.npc[buyer-self.c.n]
        stock=b.inv[item] if b else self.base[item-8]
        if cash<qty*price or stock<qty:return False
        gross=qty*price
        # Fractional fee carry prevents 1-unit splitting from erasing a 5% fee.
        raw=gross*self.c.fee_bps+self.fee_remainder if a and b else 0
        fee,rem=divmod(raw,10000)
        before=cash+(b.cash if b else self.npc[seller-self.c.n])
        if a:a.cash-=gross;a.inv[item]+=qty
        else:self.npc[buyer-self.c.n]-=gross;self.used[item]+=qty
        if b:
            b.cash+=gross-fee;b.inv[item]-=qty;b.sales+=gross-fee
        else:self.npc[seller-self.c.n]+=gross;self.base[item-8]-=qty
        if a:a.costs+=gross
        if a and b:self.fee_remainder=rem
        self.sinks['trade_fee']+=fee
        after=(a.cash if a else self.npc[buyer-self.c.n])+(b.cash if b else self.npc[seller-self.c.n])
        assert before-after==fee
        self.gross+=gross;self.trades+=1;self.trade_today[item].append((price,qty))
        self.last_trade[item]=(self.day,price)
        key=('pass' if a and a.paid else 'free' if a else 'npc')+'->'+('pass' if b and b.paid else 'free' if b else 'npc')
        self.cohort[key][0]+=gross;self.cohort[key][1]+=fee
        self.wealth_flows[(self.wealth_group[buyer] if a else 'npc')+'->'+(self.wealth_group[seller] if b else 'npc')]+=gross
        if self.trace and len(self.trade_examples)<3000:
            self.trade_examples.append(dict(day=self.day,buyer=buyer,seller=seller,item=ITEMS[item],quantity=qty,unit_price=price,gross=gross,fee=fee,seller_net=gross-fee,buyer_after=a.cash if a else self.npc[buyer-self.c.n]))
        return True

    def stage(self,a):
        level=bisect_right(XP,a.xp)
        return max((t for t in range(4) if a.skill>=STAGES[t] and level>=LEVELS[t] and (t<3 or (a.prof==0 and self.mist))),default=-1)

    def events_step(self):
        if self.c.event_mode=='off':return
        # Two candidate events, once each. No automatic budget replenishment.
        if self.day in (35,135) and self.event is None:
            kind='mist' if self.day==35 else 'pump'; budget=9000 if kind=='mist' else 6000
            mean=statistics.mean(x['active'] for x in self.days[-14:]) if self.days else self.c.n*self.c.activity
            scale=.4 if mean<500 else 1.5 if mean>1400 else 1.
            budget=round(budget*scale)
            req={24:round(120*scale),16:round(80*scale),0:round(80*scale)} if kind=='mist' else {16:round(60*scale),7:round(70*scale),2:round(70*scale),4:round(50*scale)}
            # Do not launch before products actually exist in player inventory.
            if self.npc[2]>=budget and all(sum(a.inv[i] for a in self.p)>0 for i in req):
                self.npc[2]-=budget;self.npc[3]+=budget
                self.event=dict(kind=kind,start=self.day,end=self.day+9,req=req,filled={i:0 for i in req},budget=budget,spent=0,combat=0,combat_req=round((600 if kind=='mist' else 500)*scale),contributors={})
            else:self.events.append(dict(kind=kind,start=self.day,state='not_ready'))

    def activity_step(self):
        active=[];drug_mult=1.25 if self.event and self.event['kind']=='mist' else 1.
        if self.c.event_mode=='overlap' and 270<=self.day<=300:drug_mult*=1.8
        for i,a in enumerate(self.p):
            if self.day<a.join:continue
            rate=a.activity*(1-self.c.churn if self.day>180 else 1)
            if self.r.random()>rate:continue
            active.append(i);a.active_days+=1
            # Accrue by calendar block, claim on activity, capped catch-up.
            previous=getattr(self,'allowance_claim',{}).get(i,-1)
            block=(self.day-max(1,a.join))//7
            if block>previous:
                periods=block-previous
                self.issue_to(a,min(4,periods)*self.c.allowance,'free_allowance')
                if a.paid:self.issue_to(a,min(8,periods)*self.c.pass_extra,'pass_allowance')
                self.allowance_claim[i]=block
            # First clears granted at most once; timing/success are assumptions.
            if a.q<30 and self.r.random()<.30:
                self.issue_to(a,SOURCE['q_first'][a.q],'q_first');a.q+=1;a.xp+=100
            if a.q and self.r.random()<self.c.repeat_rate:
                q=a.q-1 if self.c.repeat_strategy=='best' else self.r.randrange(a.q)
                self.issue_to(a,SOURCE['q_repeat'][q],'q_repeat')
            for j,b in enumerate(SOURCE['bounty']):
                if j not in a.bounty and a.q>=b['unlock'] and self.r.random()<.025:
                    a.bounty.add(j);self.issue_to(a,b['copper'],'bounty_first');a.xp+=100
            wins=int(self.c.tower_rate)+int(self.r.random()<self.c.tower_rate%1)
            for _ in range(wins):
                cap=10 if a.q<10 else 30 if a.q<13 else 50 if a.q<16 else 70 if a.q<20 else 100
                if a.floor<cap and self.r.random()<.65:
                    f=a.floor;a.floor+=1;a.xp+=20;self.issue_to(a,SOURCE['tower_first'][f],'tower_first')
                else:f=self.r.randrange(max(1,min(cap,a.floor or 1)))
                candidates=sorted({m for d in SOURCE['tower'][f]['monsters'] for m in MAP[d]})
                need=RECIPES[a.prof*4+max(0,self.stage(a))]
                choice=min(candidates,key=lambda m:a.inv[m]/need.get(m,.1))
                qty=self.c.bundle
                if self.c.shortage and 160<=self.day<=220 and choice in (4,5):qty=0
                a.inv[choice]+=qty;self.created[choice]+=qty;a.battles+=1
                a.durability=max(0,a.durability-2)
                if self.r.random()<self.c.drug_need*drug_mult:
                    a.need+=1;self.total_drug_need+=1
                if self.event:
                    old=self.event['contributors'].get(i,0)
                    if old<3:self.event['combat']+=1;self.event['contributors'][i]=old+1
            a.need=min(a.need,3) # outstanding requests below are per-cycle; no fake sales
        self.r.shuffle(active);return active

    def consume(self,a,repair=False):
        met=0
        # Self-use is physical consumption, not a market sale.
        while a.need:
            k=next((24+t for t in reversed(range(4)) if a.inv[24+t]),None)
            if k is None:break
            a.inv[k]-=1;self.used[k]+=1;a.need-=1;met+=1
        for prof,g in ((0,0),(2,1)):
            for t in reversed(range(4)):
                k=12+prof*4+t
                if a.inv[k] and t>a.gear[g]:
                    a.inv[k]-=1;self.used[k]+=1;a.gear[g]=t;break
        if repair and a.durability<=70:
            gross=(a.value*(100-a.durability)+199)//200
            wrap=next((16+t for t in reversed(range(4)) if a.inv[16+t]),None)
            discount=min(gross,6+2*(wrap-16)) if wrap is not None else 0
            if a.cash>=gross-discount:
                if wrap is not None:a.inv[wrap]-=1;self.used[wrap]+=1
                self.retire(a,gross-discount,'repair');a.durability=100
        return met

    def production(self):
        for j,(cap,cost) in enumerate(zip((24,18,15,70),(5,7,9,4))):
            scale=self.c.base_capacity
            if self.c.shortage and 160<=self.day<=220 and j==3:scale*=.4
            if self.event and self.event['kind']=='pump' and j==3:scale*=.8
            qty=min(round(cap*scale+(20 if j==3 and self.pump else 0)),self.npc[0]//cost,max(0,round(cap*scale*7)-self.base[j]))
            self.base[j]+=qty;self.created[8+j]+=qty;self.npc[0]-=qty*cost;self.npc[1]+=qty*cost

    def market(self,active,requests,phase):
        # requests[item] = (buyer, qty, willingness ceiling). Price/time priority,
        # daily shuffled arrivals; each order is backed by that seller's inventory.
        keys=set(requests) | (set(range(8)) if phase=='inputs' else set(range(12,28)))
        for item in sorted(keys):
            bids=requests.get(item,[])
            offers=[];want=sum(q for _,q,_ in bids)
            if 8<=item<12:offers=[(P0[item],self.c.n,self.base[item-8])]
            else:
                for i in active:
                    a=self.p[i];stock=a.inv[item]
                    if not stock:continue
                    if item<8:
                        own=RECIPES[a.prof*4+max(0,self.stage(a))].get(item,0)
                        stock=max(0,stock-2*own)
                        if self.c.hoard and i%20==0 and 80<=self.day<=250 and item in (4,5):stock=0
                    else:
                        prof=(item-12)//4
                        if prof==3:stock=max(0,stock-a.need)
                        if prof==1 and a.durability<=70:stock=max(0,stock-1)
                    if not stock:continue
                    markup=.85+(i%17)*.025
                    if self.c.dump and 251<=self.day<=280:markup*=.55
                    ask=max(1,math.ceil(self.ref[item]*markup))
                    offers.append((ask,i,stock))
            supply=sum(q for _,_,q in offers)
            offers.sort();bids.sort(key=lambda x:-x[2]);pos=0
            for buyer,qty,ceiling in bids:
                while qty and pos<len(offers):
                    price,seller,available=offers[pos]
                    if price>ceiling:break
                    if buyer==seller:
                        # Skip self order for this buyer without dropping it for others.
                        alt=next((z for z in range(pos+1,len(offers)) if offers[z][1]!=buyer and offers[z][2] and offers[z][0]<=ceiling),None)
                        if alt is None:break
                        z=alt;price,seller,available=offers[z]
                    else:z=pos
                    cash=self.p[buyer].cash if buyer<self.c.n else self.npc[buyer-self.c.n]
                    q=min(qty,available,cash//price)
                    if not q:break
                    assert self.transfer_good(buyer,seller,item,q,price)
                    if buyer<self.c.n and item<8:self.material_filled+=q
                    if buyer==self.c.n+3:
                        self.event['filled'][item]+=q;self.event['spent']+=q*price
                    qty-=q;available-=q;offers[z]=(price,seller,available)
                    while pos<len(offers) and offers[pos][2]==0:pos+=1
            if not 8<=item<12:
                # Quote signal, explicitly distinct from the recorded trade price.
                imbalance=(want-supply)/max(1,want+supply)
                self.ref[item]=max(.1,self.ref[item]*math.exp(self.c.price_response*imbalance))

    def step(self,day):
        self.day=day;self.trade_today=[[] for _ in ITEMS];start_gross=self.gross
        self.events_step();active=self.activity_step();self.production()
        if day%30==1:
            self.d30=[a.cash for a in self.p]
            ranks=sorted(range(self.c.n),key=lambda i:self.p[i].cash)
            for rank,i in enumerate(ranks):self.wealth_group[i]='bottom50' if rank<self.c.n*.5 else 'p50_90' if rank<self.c.n*.9 else 'p90_99' if rank<self.c.n*.99 else 'top1'
        available={k for k in range(12,28) if any(self.p[i].inv[k] for i in active)}
        met=0;need_free=met_free=blocked_free=0;need_paid=met_paid=0
        # Count the active outstanding demand ONCE for this day, before self-use.
        need_by={i:self.p[i].need for i in active}
        for i in active:met+=self.consume(self.p[i])
        requests=defaultdict(list);crafters=[]
        for i in active:
            a=self.p[i];t=self.stage(a)
            if t<0 or self.r.random()>self.c.crafting:continue
            if t not in a.learned:
                cost=40+20*t
                if self.recipe_stock[a.prof][t] and self.pay_npc(a,cost,4):
                    self.recipe_stock[a.prof][t]-=1;a.learned.add(t)
                else:continue
            recipe=RECIPES[a.prof*4+t];crafters.append((i,t))
            for item,q in recipe.items():
                missing=max(0,q-a.inv[item])
                if missing:
                    ceiling=math.ceil(P0[item]*1.8*max(.6,(a.cash/500)**self.c.demand_elasticity))
                    requests[item].append((i,missing,ceiling))
                    if item<8:self.material_requests+=missing
        if self.event:
            for item,req in self.event['req'].items():
                if item<12:
                    q=min(req-self.event['filled'][item],max(1,math.ceil(req/10)))
                    if q:requests[item].append((self.c.n+3,q,math.ceil(P0[item]*3)))
        self.market(active,requests,'inputs')
        for i,t in crafters:
            a=self.p[i];recipe=RECIPES[a.prof*4+t];item=12+a.prof*4+t
            # Finite personal shelf; prevents unlimited valueless crafting.
            if a.cash<1 or a.inv[item]>=8 or any(a.inv[k]<q for k,q in recipe.items()):continue
            for k,q in recipe.items():a.inv[k]-=q;self.used[k]+=q
            a.inv[item]+=1;self.created[item]+=1;a.crafts+=1;self.retire(a,1,'craft')
            diff=a.skill-STAGES[t];a.skill=min(100,a.skill+(3 if diff<10 else 2 if diff<20 else 1 if diff<30 else 0))
        requests=defaultdict(list)
        for i in active:
            a=self.p[i];met+=self.consume(a)
            wealth=max(.6,(a.cash/500)**self.c.demand_elasticity)
            if a.need:
                # Choose cheapest currently quoted usable dose, not a forced premium.
                item=min([k for k in range(24,28) if k in available] or [24],key=lambda k:self.ref[k])
                ceiling=math.ceil(30*wealth)
                requests[item].append((i,a.need,ceiling))
            if a.durability<=70:
                gross=(a.value*(100-a.durability)+199)//200
                # A wrap discount must cost less than the saving to be rational.
                t=max(range(4),key=lambda t:(6+2*t)-self.ref[16+t])
                if self.ref[16+t]<6+2*t:requests[16+t].append((i,1,min(gross,6+2*t)))
            level=bisect_right(XP,a.xp)
            tier=max((t for t in range(4) if level>=LEVELS[t]),default=-1)
            for prof,g in ((0,0),(2,1)):
                if tier>a.gear[g]:
                    options=[t for t in range(a.gear[g]+1,tier+1) if 12+prof*4+t in available]
                    target=max(options) if options else a.gear[g]+1
                    item=12+prof*4+target;requests[item].append((i,1,math.ceil(P0[item]*1.25*wealth)))
        if self.event:
            for item,req in self.event['req'].items():
                if item>=12:
                    q=min(req-self.event['filled'][item],max(1,math.ceil(req/10)))
                    if q:requests[item].append((self.c.n+3,q,math.ceil(P0[item]*3)))
        self.market(active,requests,'products')
        for i in active:
            a=self.p[i];met+=self.consume(a,repair=True)
            need=need_by[i];fulfilled=max(0,need-a.need)
            if a.paid:need_paid+=need;met_paid+=fulfilled
            else:
                need_free+=need;met_free+=fulfilled
                if a.need and a.cash<min(math.ceil(self.ref[k]*.85) for k in range(24,28)):blocked_free+=a.need
            # Unmet use is counted, not removed invisibly from demand. It expires
            # because each cycle is a fresh optional battle-consumption episode.
            a.need=0
        if self.event and day==self.event['end']:
            e=self.event;success=all(e['filled'][k]>=q*.7 for k,q in e['req'].items()) and e['combat']>=.8*e['combat_req']
            assert e['spent']<=e['budget']
            if success:
                if e['kind']=='pump':self.pump=True
                else:self.mist=True
            self.npc[2]+=self.npc[3];self.npc[3]=0
            self.events.append({k:v for k,v in e.items() if k!='contributors'}|{'state':'success' if success else 'failure'})
            self.event=None
        # Daily global audit independent from individual transfer assertions.
        assert self.total_money()==self.open_money+sum(self.issue.values())-sum(self.sinks.values())
        assert min(self.npc)>=0 and all(a.cash>=0 and min(a.inv)>=0 for a in self.p)
        for k in range(28):
            stock=sum(a.inv[k] for a in self.p)+(self.base[k-8] if 8<=k<12 else 0)
            assert stock==self.created[k]-self.used[k],(day,k,stock,self.created[k],self.used[k])
        price={}
        for k,trades in enumerate(self.trade_today):
            if trades:
                # Exact quantity-weighted median of today's executed trades.
                v=sorted(trades);target=(sum(q for _,q in v)+1)//2;acc=0
                for px,q in v:
                    acc+=q
                    if acc>=target:price[k]=px;break
        row=dict(day=day,active=len(active),free_need=need_free,free_met=met_free,paid_need=need_paid,paid_met=met_paid,free_cash_blocked=blocked_free,gross=self.gross-start_gross,issuance=sum(self.issue.values()),sink=sum(self.sinks.values()),money=self.total_money(),money_error=0,pump=int(self.pump),event=self.event['kind'] if self.event else '',**{f'price_{k}':price.get(k) for k in range(8,28)})
        self.days.append(row)
        if day%30==0:
            eligible=[a.cash-self.d30[i] for i,a in enumerate(self.p) if not a.paid and a.join<=day-30]
            self.d30_delta.append(statistics.median(eligible) if eligible else None)

    def run(self):
        self.allowance_claim={}
        for day in range(1,self.c.days+1):self.step(day)
        return self

    def summary(self):
        free=[a.cash for a in self.p if not a.paid and a.join<=self.c.days]
        paid=[a.cash for a in self.p if a.paid and a.join<=self.c.days]
        def quant(xs,q):return sorted(xs)[min(len(xs)-1,int((len(xs)-1)*q))] if xs else None
        # Fixed basket of base armor, wrap, weapon, salve; missing trade coverage
        # invalidates the index, never forward-fills prices.
        indices=[];coverage=[]
        for start in range(0,len(self.days)-29,30):
            window=self.days[start:start+30];values=[]
            for k in (8,9,10,11,24):
                px=[r[f'price_{k}'] for r in window if r[f'price_{k}'] is not None]
                if px:values.append(statistics.median(px)*(4 if k==24 else 1))
            coverage.append(len(values)/5)
            indices.append(sum(values)/(8+10+12+6+24*4) if len(values)==5 else None)
        changes=[abs(b/a-1) for a,b in zip(indices,indices[1:]) if a is not None and b is not None]
        last=self.days[-90:];fn=sum(r['free_need'] for r in last);fm=sum(r['free_met'] for r in last)
        pn=sum(r['paid_need'] for r in last);pm=sum(r['paid_met'] for r in last)
        missing=sum(r['free_cash_blocked'] for r in last)
        status={'accounting':True,'free_drug_fill_90pct':fn>0 and fm/fn>=.9,'free_cash_unmet_zero':missing==0,'free_median_30d_cash_nonnegative':bool(self.d30_delta) and all(x is not None and x>=0 for x in self.d30_delta[-3:]),'price_coverage_complete':bool(coverage) and all(x==1 for x in coverage[-3:]),'price_change_20pct':bool(changes) and max(changes)<=.2}
        return dict(config=asdict(self.c),seed=self.seed,trades=self.trades,gross=self.gross,opening_money=self.open_money,issuance=dict(self.issue),sinks=dict(self.sinks),end_money=self.total_money(),free_cash_p10=quant(free,.1),free_cash_p50=quant(free,.5),paid_cash_p50=quant(paid,.5),free_fill_last90=fm/fn if fn else None,paid_fill_last90=pm/pn if pn else None,free_cash_blocked_last90=missing,free_median_delta_last3=self.d30_delta[-3:],material_fill=self.material_filled/max(1,self.material_requests),basket_index_30d=indices,basket_coverage_30d=coverage,max_30d_change=max(changes) if changes else None,events=self.events,checks=status,all_checks_pass=all(status.values()),profession=[dict(prof=p,crafts=sum(a.crafts for a in self.p if a.prof==j),skill_median=statistics.median(a.skill for a in self.p if a.prof==j),sales=sum(a.sales for a in self.p if a.prof==j),purchases=sum(a.costs for a in self.p if a.prof==j)) for j,p in enumerate(PROFS)],flows=dict(self.cohort),wealth_flows=dict(self.wealth_flows))
