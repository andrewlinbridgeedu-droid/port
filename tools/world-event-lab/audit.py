"""Reproducible design sensitivity sets, not telemetry or market forecasts."""
import hashlib
import itertools
import json
from pathlib import Path
from model import config,simulate_event,operate,money,run,VERSION

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/development/world-event-lab-20260927'

def main():
    event=[]
    for n,share,profile,supply,attendance,ordinary in itertools.product(
            (20,100,400),(.5,.7,.9),('equal','skilled_minority'),('both','a_short'),(.6,.85,1),(.65,.85)):
        values=dict(participants=n,share_a=share,trials=1000,attendance=attendance,public_a=ordinary,public_b=ordinary)
        if profile=='skilled_minority':values.update(hard_b=1,hard_success_b=.8,node_b=.75,boss_b=.7)
        if supply=='a_short':values['supply_a']=8
        p=config(values);e=simulate_event(p)
        assert abs(sum(e['outcomes'].values())-1)<1e-10
        event.append(dict(n=n,share=share,profile=profile,supply=supply,attendance=attendance,ordinary=ordinary,result=e))
    print('Event scenarios:',len(event),flush=True)
    project=[]
    for price,demand,wallet,raw,guard in itertools.product((30,40,50,60),(0,10,24,25,30,40,50),(0,800,3000,6000),(25,50),(True,False)):
        p=config(dict(kit_price=price,orders_a=demand,buyer_budget=wallet,raw_capacity=raw,launch_guard=guard))
        r=operate(p,'a');assert r['conservation_error']==0
        project.append(dict(price=price,demand=demand,wallet=wallet,raw=raw,guard=guard,
                            **{k:v for k,v in r.items() if k!='rows'}))
    print('Project scenarios:',len(project),flush=True)
    monetary=[]
    for dau,monthly,other,fresh,sink,fixed in itertools.product((.2,.5,.8),(0,.3,.6),(0,8,40),(0,5,20),(True,False),(True,False)):
        p=config(dict(dau=dau,monthly=monthly,other_cash=other,fresh=fresh,external_sink=sink,fixed_active_cohort=fixed))
        for days,interval in itertools.product((180,365,730),(1,7,14)):
            monetary.append(dict(dau=dau,monthly=monthly,other_cash=other,fresh=fresh,
                                 external_sink=sink,fixed_active_cohort=fixed,**money(p,days,interval)))
    print('Currency observations:',len(monetary),flush=True)
    presets={
        'recommended':run(dict(kit_price=60,launch_guard=True,public_a=.85,public_b=.85)),
        'recommended_minority':run(dict(kit_price=60,launch_guard=True,public_a=.85,public_b=.85,hard_b=1,hard_success_b=.8,node_b=.75,boss_b=.7)),
        'recommended_no_customers':run(dict(kit_price=60,launch_guard=True,orders_a=0,orders_b=0)),
        'baseline':run(),
        'minority_prepared':run(dict(hard_b=1,hard_success_b=.8,node_b=.75,boss_b=.7)),
        'majority_shortage':run(dict(supply_a=8)),
        'no_customers':run(dict(orders_a=0,orders_b=0)),
        'no_players':run(dict(participants=0)),
    }
    data=dict(version=VERSION,event=event,project=project,money=monetary,presets=presets,
              source_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in Path(__file__).parent.glob('*.py')})
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'results.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    summary=dict(events=len(event),projects=len(project),currency_observations=len(monetary),
                 presets={k:dict(outcomes=v['event']['outcomes'],
                     mortality=v['event']['mortality'],
                     project_net=[x['net_if_wins'] for x in v['projects']],
                     money365=[x for x in v['money'] if x['days']==365]) for k,v in presets.items()})
    (OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
