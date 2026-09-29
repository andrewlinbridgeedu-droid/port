"""V3 mature-server feasibility model. Fixed candidate prices, not a CPI forecast.
Actual independent wallets, finite imports, provenance lots and funded projects.
Combat, participation and demand are explicit assumptions, not measured gameplay.
"""
from dataclasses import dataclass, field, asdict
from collections import Counter, defaultdict, deque
from pathlib import Path
import csv, hashlib, json, random, statistics
from salve_policy import Wallet, Ledger, buy_guarantee

SOURCE=json.loads(Path(__file__).with_name('source_inputs.json').read_text())
MAP={'D01':(2,3),'D02':(4,1),'D03':(1,5),'D04':(2,3),'D05':(0,6),'D06':(3,7),'D07':(2,7),'D08':(2,3),'D09':(0,6),'D10':(1,5,4),'D11':(4,0)}
RAW=(0,3,7,5)
PRICE=(4,4,4,4,4,6,4,4,8,10,12,6,4,6,5,16)
RECIPES=({0:1,8:1},{3:1,9:1},{7:1,10:1},{5:1,11:1,12:1,14:2})
OUTPUT=(4,3,4,2)

@dataclass(frozen=True)
class Config:
    name:str='control'
    n:int=2000
    days:int=365
    cash_window:int=0
    war:bool=False
    preparation:int=7
    procurement_mint:bool=False
    faction_share:float=.5
    participation:float=.35
    win_chance:float=.45
    craft_chance:float=.45
    campaign_starts:tuple=(120,240)

@dataclass
class Player:
    cash:int
    paid:bool
    activity:float
    prof:int
    faction:int
    value:int
    inv:list=field(default_factory=lambda:[0]*16)
    basis:list=field(default_factory=lambda:[0.]*16)
    lots:dict=field(default_factory=lambda:{i:deque() for i in range(12,16)})
    durability:int=100
    last_cash_block:int=-1
    last_allowance:int=-1
    crafts:int=0
    shelf_blocked:int=0
    craft_opportunities:int=0
    sales_net:int=0
    sold_cost:float=0
    mint:int=0
    investment:int=0
    refund:int=0
    opening:int=0

class Sim:
    def __init__(self,c,seed):
        self.c,self.seed=c,seed
        self.r=random.Random(seed)
        # Exogenous draws have independent stream: cash policy cannot alter demand draws.
        self.behavior=random.Random(seed+100000)
        self.p=[]
        for i in range(c.n):
            cash=int(self.r.lognormvariate(7.1,1.15))
            a=Player(cash,self.r.random()<.3,min(.99,.5*self.r.uniform(.35,1.65)),i%4,
                     int(self.r.random()>=c.faction_share),720 if cash>5000 else 400 if cash>1000 else 120)
            a.opening=cash; self.p.append(a)
        self.merchant=1500;self.treasury=30000;self.project=[0,0]
        self.base=[20,30,40,80];self.transit=[0]*4;self.project_stock=[0,0]
        self.created=Counter({8+i:q for i,q in enumerate(self.base)});self.used=Counter()
        self.mint=Counter();self.retired=Counter();self.ledger=Ledger()
        self.daily=[];self.trades=[];self.events=[];self.current=None
        self.produced=Counter();self.first_sold=Counter();self.sale_delays=defaultdict(list)
        self.day=0;self.opening=self.money();self.open_materials=dict(self.created)
        self.raw_bids_seen=Counter();self.phase_stats=defaultdict(Counter)
        self.repair_bills=[];self.repair_saved=0;self.npc_gross_today=0

    def money(self):return sum(a.cash for a in self.p)+self.merchant+self.treasury+sum(self.project)
    def total_retired(self):return sum(self.retired.values())+self.ledger.system_retired+self.ledger.trade_retired
    def mint_player(self,a,q,key):a.cash+=q;a.mint+=q;self.mint[key]+=q
    def draw_lots(self,a,item,q):
        result=[]
        while q:
            lot=a.lots[item][0];take=min(q,lot[0]);result.append([take]+lot[1:]);lot[0]-=take;q-=take
            if not lot[0]:a.lots[item].popleft()
        return result

    def consume(self,a,item,q):
        assert a.inv[item]>=q
        cost=0
        if item>=12:cost=sum(l[0]*l[1] for l in self.draw_lots(a,item,q))
        else:cost=q*a.basis[item]
        a.inv[item]-=q;self.used[item]+=q
        return cost

    def trade(self,seller,buyer,item,q,phase,project=None):
        s=self.p[seller];b=self.p[buyer] if buyer is not None else None
        price=PRICE[item];available_cash=b.cash if b else self.project[project]
        q=min(q,s.inv[item],available_cash//price)
        if q<=0 or seller==buyer:return 0
        gross=q*price;fee,rem=divmod(gross*5+self.ledger.trade_fee_remainder,100)
        self.ledger.trade_fee_remainder=rem;self.ledger.trade_retired+=fee
        before_s=s.cash;before_b=available_cash;s.cash+=gross-fee;s.sales_net+=gross-fee
        if b:b.cash-=gross
        else:self.project[project]-=gross
        if item>=12:
            lots=self.draw_lots(s,item,q);s.sold_cost+=sum(l[0]*l[1] for l in lots)
            for lot in lots:
                if not lot[4]:
                    self.first_sold[(lot[2],item)]+=lot[0]
                    self.sale_delays[item].extend([self.day-lot[3]]*lot[0])
                if b:b.lots[item].append([lot[0],price,lot[2],lot[3],True])
        else:s.sold_cost+=q*s.basis[item]
        s.inv[item]-=q
        if b:
            if item<12:b.basis[item]=(b.inv[item]*b.basis[item]+gross)/(b.inv[item]+q)
            b.inv[item]+=q
        else:self.project_stock[project]+=q
        self.trades.append(dict(day=self.day,phase=phase,seller=seller,buyer=buyer if b else f'project{project}',
            item=item,quantity=q,price=price,gross=gross,fee=fee,seller_net=gross-fee,
            seller_before=before_s,seller_after=s.cash,buyer_before=before_b,buyer_after=before_b-gross,
            buyer_plan=('paid' if b.paid else 'free') if b else 'project'))
        return q

    def markets(self,active):
        books=defaultdict(deque)
        for i in active:
            a=self.p[i]
            for item in list(RAW)+list(range(12,16)):
                # Own-prof input buffer is 2 batches; personal medicine remains available to buy/use.
                reserve=2*RECIPES[a.prof].get(item,0)
                if a.inv[item]>reserve:books[item].append([i,a.inv[item]-reserve])
        return books

    def buy(self,i,item,q,books,phase,project=None):
        got=0;book=books[item];deferred=[]
        while q>0 and book:
            seller,offered=book.popleft()
            if seller==i:deferred.append([seller,offered]);continue
            count=self.trade(seller,i,item,min(q,offered),phase,project)
            got+=count;q-=count;offered-=count
            if offered and self.p[seller].inv[item]:book.appendleft([seller,offered])
            if not count and self.p[seller].inv[item]:break
        book.extend(deferred)
        return got

    def import_goods(self):
        for j,q in enumerate(self.transit):self.base[j]+=q
        self.transit=[0]*4
        # Fixed published priority; starvation diagnostics must reveal consequences.
        for j,(cost,cap,limit) in enumerate(zip((7,9,11,5),(20,30,40,80),(60,90,120,240))):
            q=min(cap,limit-self.base[j],self.merchant//cost)
            self.merchant-=q*cost;self.retired['import_outflow']+=q*cost
            self.transit[j]=q;self.created[8+j]+=q

    def event_start(self,start):
        self.current=dict(start=start,end=start+2,opened=self.day,investors=[{},{}],seed=[0,0],
                          bought=[0,0],wins=[0,0],attempts=[0,0],medical_used=[0,0],target=[150,150])
        for f in (0,1):
            if self.c.procurement_mint:self.project[f]+=3000;self.mint['procurement_authorization']+=3000
            else:
                funds=min(3000,self.treasury);self.treasury-=funds;self.project[f]+=funds
            self.current['seed'][f]=self.project[f]
        for i,a in enumerate(self.p):
            if (i+start)%5==0 and a.cash>=50:
                a.cash-=50;a.investment+=50;self.project[a.faction]+=50
                self.current['investors'][a.faction][i]=50

    def event_end(self):
        e=self.current
        # Physical stock remains in faction depot; unused cash distributed pro-rata.
        for f in (0,1):
            opening=e['seed'][f]+sum(e['investors'][f].values());cash=self.project[f]
            for i,amount in e['investors'][f].items():
                refund=cash*amount//opening;self.p[i].cash+=refund;self.p[i].refund+=refund;self.project[f]-=refund
            self.treasury+=self.project[f];self.project[f]=0
        # A feasibility gate only; no boss AI, narrative death, profits or contracts invented.
        e['logistics_and_combat_ready']=[e['bought'][f]>=150 and e['wins'][f]>=100 for f in (0,1)]
        e['remaining_medical_stock']=list(self.project_stock)
        self.events.append(e);self.current=None

    def step(self,day):
        self.day=day;old_mint=sum(self.mint.values());old_retired=self.total_retired();old_trades=len(self.trades)
        if self.c.war and day in tuple(start-self.c.preparation for start in self.c.campaign_starts):self.event_start(day+self.c.preparation)
        phase='action' if self.current and day>=self.current['start'] else 'preparation' if self.current else 'normal'
        self.import_goods();active=[];demand={};attempts={}
        for i,a in enumerate(self.p):
            # Pre-draw all exogenous variables, independent of affordability and cash policy.
            rng=self.behavior
            on=rng.random()<a.activity;tower=rng.random()<.65;drug=rng.random()<.18
            floor=rng.randrange(100);join=rng.random()<self.c.participation
            win=rng.random()<self.c.win_chance;war_drug=rng.random()<.4;craft=rng.random()<self.c.craft_chance
            if not on:continue
            active.append(i);demand[i]=int(tower and drug);attempts[i]=(phase=='action' and join,win,war_drug,craft)
            block=(day-1)//7
            if block>a.last_allowance:
                elapsed=block-a.last_allowance
                self.mint_player(a,28*min(4,elapsed),'free_allowance')
                if a.paid:self.mint_player(a,28*min(8,elapsed),'pass_allowance')
                a.last_allowance=block
            cash_block=(day-1)//self.c.cash_window if self.c.cash_window else day
            if not self.c.cash_window or cash_block>a.last_cash_block:
                self.mint_player(a,SOURCE['q_repeat'][-1],'q30_repeat');a.last_cash_block=cash_block
            if tower:
                choices=sorted({m for enemy in SOURCE['tower'][floor]['monsters'] for m in MAP[enemy]})
                item=RAW[a.prof] if RAW[a.prof] in choices else choices[(i+day)%len(choices)]
                a.inv[item]+=4;self.created[item]+=4;a.durability=max(0,a.durability-2)
        # Rotate processing order to avoid permanent ID priority; randomness does not affect exogenous draws.
        self.r.shuffle(active)
        books=self.markets(active)
        for i in active:
            a=self.p[i];item=12+a.prof;recipe=RECIPES[a.prof]
            if not attempts[i][3]:continue
            a.craft_opportunities+=1
            if a.inv[item]+OUTPUT[a.prof]>12:a.shelf_blocked+=1;continue
            for k,q in recipe.items():
                missing=max(0,q-a.inv[k])
                if not missing:continue
                if k<8:self.raw_bids_seen[k]+=missing
                if 8<=k<12:
                    n=min(missing,self.base[k-8],a.cash//PRICE[k]);gross=n*PRICE[k]
                    a.basis[k]=(a.inv[k]*a.basis[k]+gross)/(a.inv[k]+n) if a.inv[k]+n else 0
                    a.cash-=gross;self.merchant+=gross;self.base[k-8]-=n;a.inv[k]+=n
                    self.npc_gross_today+=gross
                else:self.buy(i,k,missing,books,'input')
            if a.cash<2 or any(a.inv[k]<q for k,q in recipe.items()):continue
            cost=2+sum(self.consume(a,k,q) for k,q in recipe.items())
            a.cash-=2;self.retired['craft']+=2;a.crafts+=1
            q=OUTPUT[a.prof];a.inv[item]+=q;a.lots[item].append([q,cost/q,i,day,False]);self.created[item]+=q
            self.produced[(i,item)]+=q
        books=self.markets(active)
        if self.current:
            e=self.current;remaining_days=e['end']-day+1
            for f in (0,1):
                missing=e['target'][f]-e['bought'][f]
                q=(missing+remaining_days-1)//remaining_days
                e['bought'][f]+=self.buy(None,15,q,books,'project',f)
        stats=Counter()
        for i in active:
            a=self.p[i];fight,win,war_drug,_=attempts[i];plan='paid' if a.paid else 'free'
            if fight:
                f=a.faction;e=self.current;e['attempts'][f]+=1;e['wins'][f]+=int(win)
                a.durability=max(0,a.durability-(2 if win else 5))
                if war_drug:
                    if self.project_stock[f]:
                        self.project_stock[f]-=1;self.used[15]+=1;e['medical_used'][f]+=1
                        stats[plan+'_event_craft_used']+=1;stats[plan+'_demand']+=1
                    else:demand[i]+=1
            for _ in range(demand[i]):
                stats[plan+'_demand']+=1
                if not a.inv[15]:self.buy(i,15,1,books,'personal')
                if a.inv[15]:self.consume(a,15,1);stats[plan+'_craft_used']+=1
                else:
                    wallet=Wallet(a.cash)
                    if buy_guarantee(wallet,self.ledger):
                        a.cash=wallet.cash;stats[plan+'_guarantee_used']+=1
                        # Bound dose is created and consumed immediately, never enters market lots.
                        self.created['system_salve']+=1;self.used['system_salve']+=1
                    else:stats[plan+'_unmet']+=1
            if a.durability<=70:
                bill=(a.value*(100-a.durability)+199)//200
                self.repair_bills.append(min(8,bill))
                if not a.inv[13] and min(8,bill)>PRICE[13]:self.buy(i,13,1,books,'repair')
                saving=min(8,bill) if a.inv[13] else 0
                if a.cash>=bill-saving:
                    if saving:self.consume(a,13,1);self.repair_saved+=saving
                    a.cash-=bill-saving;self.retired['repair']+=bill-saving;a.durability=100
                else:stats[plan+'_repair_blocked']+=1
        if self.current and day==self.current['end']:self.event_end()
        self.audit()
        row=dict(day=day,phase=phase,active=len(active),money=self.money(),mint=sum(self.mint.values()),
                 outflow=self.total_retired(),daily_mint=sum(self.mint.values())-old_mint,
                 daily_outflow=self.total_retired()-old_retired,
                 p2p_and_project_gross=sum(t['gross'] for t in self.trades[old_trades:]),npc_gross=self.npc_gross_today,
                 merchant_cash=self.merchant,base_stock=sum(self.base),in_transit=sum(self.transit),
                 crafted_salve_stock=sum(a.inv[15] for a in self.p),event_stock=sum(self.project_stock))
        for plan in ('free','paid'):
            for key in ('demand','craft_used','event_craft_used','guarantee_used','unmet','repair_blocked'):
                row[plan+'_'+key]=stats[plan+'_'+key]
        self.daily.append(row);self.phase_stats[phase].update(stats)

    def audit(self):
        assert self.money()==self.opening+sum(self.mint.values())-self.total_retired()
        assert min(self.merchant,self.treasury,*self.project)>=0
        stocks=Counter()
        for a in self.p:
            assert a.cash>=0 and min(a.inv)>=0
            for k,q in enumerate(a.inv):stocks[k]+=q
            for k in range(12,16):assert sum(l[0] for l in a.lots[k])==a.inv[k]
        for j,q in enumerate(self.base):stocks[8+j]+=q+self.transit[j]
        stocks[15]+=sum(self.project_stock)
        for k in list(range(16))+['system_salve']:assert stocks[k]==self.created[k]-self.used[k],(k,stocks[k],self.created[k],self.used[k])

    def run(self):
        self.repair_bills=[];self.repair_saved=0
        for d in range(1,self.c.days+1):self.npc_gross_today=0;self.step(d)
        return self.summary()

    def summary(self):
        metrics={}
        for phase,stats in self.phase_stats.items():
            metrics[phase]={}
            for plan in ('free','paid'):
                d=stats[plan+'_demand'];c=stats[plan+'_craft_used']+stats[plan+'_event_craft_used'];g=stats[plan+'_guarantee_used']
                metrics[phase][plan]=dict(demand=d,craft_fill=c/d if d else None,guarantee_fill=g/d if d else None,total_fill=(c+g)/d if d else None)
        professions=[]
        for prof in range(4):
            ps=[(i,a) for i,a in enumerate(self.p) if a.prof==prof];q=sum(self.produced[(i,12+prof)] for i,a in ps)
            sold=sum(self.first_sold[(i,12+prof)] for i,a in ps)
            professions.append(dict(prof=prof,produced=q,first_sale_units=sold,sell_through=sold/q if q else None,
                cash_trading_contribution=sum(a.sales_net-a.sold_cost for i,a in ps),
                shelf_blocked=sum(a.shelf_blocked for i,a in ps),craft_opportunities=sum(a.craft_opportunities for i,a in ps)))
        item_metrics=[]
        for item in range(12,16):
            ts=[t for t in self.trades if t['item']==item];prices=sorted(t['price'] for t in ts)
            item_metrics.append(dict(item=item,gross=sum(t['gross'] for t in ts),quantity=sum(t['quantity'] for t in ts),
                median_price=statistics.median(prices) if prices else None,no_trade_cycles=self.c.days-len({t['day'] for t in ts}),
                median_first_sale_delay=statistics.median(self.sale_delays[item]) if self.sale_delays[item] else None,
                inventory=sum(a.inv[item] for a in self.p)))
        wallets={}
        for plan in (False,True):
            group=[a for a in self.p if a.paid==plan];cash=sorted(a.cash for a in group)
            wallets['paid' if plan else 'free']=dict(p10=cash[len(cash)//10],p50=statistics.median(cash),
                median_cash_delta_excluding_mint=statistics.median(a.cash-a.opening-a.mint for a in group))
        return dict(config=asdict(self.c),seed=self.seed,opening_money=self.opening,end_money=self.money(),
            mint=dict(self.mint),outflow=dict(self.retired)|{'system_guarantee':self.ledger.system_retired,'trade_fee':self.ledger.trade_retired},
            gross=sum(t['gross'] for t in self.trades),npc_gross=sum(r['npc_gross'] for r in self.daily),
            trade_count=len(self.trades),metrics=metrics,professions=professions,items=item_metrics,wallets=wallets,
            repair_savings=self.repair_saved,median_repair_value=statistics.median(self.repair_bills) if self.repair_bills else None,
            events=self.events,investment_paid=sum(a.investment for a in self.p),investment_refunded=sum(a.refund for a in self.p),
            raw_opportunity_value='UNKNOWN; fixed raw quote is not executable counterfactual depth',
            limitations=['Mature-only, equal profession population; no new recipe/skill progression.',
                'Fixed candidate quotes; actual transfers are observed but no price stability conclusion is possible.',
                'Combat participation, wins and drug use are exogenous; wealth does not cause victory in this model.',
                'No investment operating revenue or dividends simulated; only funded procurement and remaining cash refund.',
                'Only ordinary relic wear/copper repair/wrap modeled; no newly invented relic activation fees.',
                'Two campaign logistics probes, not the full six-event or NPC death narrative implementation.',
                'Manufacturing cost basis is actual cash only; self-gathered raw opportunity cost remains unknown.',
                'Trade contribution includes raw/component resale; not pure crafting RPM or net annual professional profit.'])
