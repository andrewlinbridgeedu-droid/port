"""Predeclared scenario grid and multi-seed runner. No post-hoc pass thresholds."""
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import replace, asdict
from pathlib import Path
import argparse, csv, hashlib, json, statistics, time
from model import Config, Sim

def configs(days=365):
    base=Config(days=days)
    rows=[base]
    for name,kw in [
        ('cold',dict(activity=.2,pass_share=.1)),
        ('hot',dict(activity=.8,pass_share=.6)),
        ('no_pass',dict(pass_share=0)),
        ('all_pass',dict(pass_share=1)),
        ('no_events',dict(event_mode='off')),
        ('supply_2x',dict(bundle=4,base_capacity=2)),
        ('supply_3x',dict(bundle=6,base_capacity=3)),
        ('allowance_14',dict(allowance=14,pass_extra=14)),
        ('allowance_42',dict(allowance=42,pass_extra=42)),
        ('supply2_allowance14',dict(bundle=4,base_capacity=2,allowance=14,pass_extra=14)),
        ('supply2_fee8',dict(bundle=4,base_capacity=2,fee_bps=800)),
        ('low_crafting',dict(crafting=.2)),
        ('high_crafting',dict(crafting=.8)),
        ('low_tower',dict(tower_rate=.2)),
        ('high_tower',dict(tower_rate=1.3)),
        ('repeat_best',dict(repeat_rate=1,repeat_strategy='best')),
        ('repeat_heavy',dict(repeat_rate=1,repeat_strategy='best',tower_rate=.2)),
        ('hoarding',dict(hoard=True)),
        ('dump',dict(hoard=True,dump=True)),
        ('supply_shock',dict(shortage=True)),
        ('overlap_shock',dict(shortage=True,event_mode='overlap')),
        ('churn',dict(churn=.6,newcomers=.02)),
        ('new_server',dict(veterans=0,newcomers=.3)),
        ('mature_server',dict(veterans=.8,newcomers=0)),
        ('wealth_elastic',dict(demand_elasticity=.4)),
        ('slow_prices',dict(price_response=.0125)),
        ('fast_prices',dict(price_response=.05)),
    ]:rows.append(replace(base,name=name,**kw))
    return rows

def one(job):
    conf,seed,out=job;start=time.monotonic()
    sim=Sim(conf,seed,trace=(conf.name=='baseline' and seed==101)).run()
    target=Path(out)/f'{conf.name}-{seed}';target.mkdir(parents=True,exist_ok=True)
    result=sim.summary();result['runtime_seconds']=round(time.monotonic()-start,2)
    (target/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    with (target/'daily.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=sim.days[0]);w.writeheader();w.writerows(sim.days)
    if sim.trade_examples:(target/'trade_examples.json').write_text(json.dumps(sim.trade_examples,indent=2)+'\n')
    return result

def aggregate(out):
    rows=[json.loads(p.read_text()) for p in Path(out).glob('*/summary.json')]
    table=[]
    for name in sorted({r['config']['name'] for r in rows}):
        group=[r for r in rows if r['config']['name']==name]
        record={'scenario':name,'seeds':len(group),'days':group[0]['config']['days'],'passed':sum(r['all_checks_pass'] for r in group)}
        for key in ('free_fill_last90','paid_fill_last90','free_cash_p10','free_cash_p50','paid_cash_p50','free_cash_blocked_last90','material_fill','max_30d_change'):
            vals=[r[key] for r in group if r[key] is not None]
            record[key+'_mean']=statistics.mean(vals) if vals else None
            record[key+'_min']=min(vals) if vals else None
            record[key+'_max']=max(vals) if vals else None
        record['issue_mean']=statistics.mean(sum(r['issuance'].values()) for r in group)
        record['sink_mean']=statistics.mean(sum(r['sinks'].values()) for r in group)
        record['failed_checks']=';'.join(k for k in group[0]['checks'] if any(not r['checks'][k] for r in group))
        table.append(record)
    with (Path(out)/'comparison.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=table[0]);w.writeheader();w.writerows(table)
    return table

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--days',type=int,default=365);p.add_argument('--workers',type=int,default=4);p.add_argument('--seeds',default='101,211,307,401,503');p.add_argument('--only',default='');args=p.parse_args()
    grid=configs(args.days)
    if args.only:grid=[c for c in grid if c.name in args.only.split(',')]
    out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
    seeds=[int(x) for x in args.seeds.split(',')]
    manifest={'configs':[asdict(c) for c in grid],'seeds':seeds,'source_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in Path(__file__).parent.glob('*.py')},'gates':{'accounting_error':0,'free_drug_fill_last90':.9,'free_cash_blocked_last90':0,'free_median_30d_cash_last3':'all >= 0','basket_last3_coverage':1.,'max_30d_price_change':.2},'note':'Experimental gates, not proof of no inflation; controlled base prices included in fixed basket.'}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    jobs=[(c,s,str(out)) for c in grid for s in seeds]
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        futures=[pool.submit(one,j) for j in jobs]
        for count,f in enumerate(as_completed(futures),1):
            r=f.result();print(count,len(jobs),r['config']['name'],r['seed'],'fill',round(r['free_fill_last90'] or 0,3),'pass',r['all_checks_pass'],'sec',r['runtime_seconds'],flush=True)
    aggregate(out)
