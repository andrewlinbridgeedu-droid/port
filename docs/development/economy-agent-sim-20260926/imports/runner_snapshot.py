"""Predeclared scenario grid and multi-seed runner. No post-hoc pass thresholds."""
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import replace, asdict
from pathlib import Path
import argparse, csv, hashlib, json, statistics, time
from model import Config, Sim

def configs(days=365):
    base=Config(days=days,bundle=4,base_capacity=2,veterans=1,newcomers=0,repeat_strategy='best',repeat_rate=1,expense_stress=True)
    return [replace(base,name=f'w{w}_import{cost}_batch{batch}',repeat_window=w,import_cost=cost,leather_batch=batch) for w,cost,batch in ((7,12,1),(7,12,6),(14,12,6),(14,6,6))]

def one(job):
    conf,seed,out=job;start=time.monotonic()
    sim=Sim(conf,seed,trace=(conf.name=='baseline' and seed==101)).run()
    target=Path(out)/f'{conf.name}-{seed}';target.mkdir(parents=True,exist_ok=True)
    result=sim.summary();result['end_player_cash']=sum(a.cash for a in sim.p);result['end_npc_cash']=sim.npc;result['professions']=[dict(profession=p,craft_batches=sum(a.crafts for a in sim.p if a.prof==p),sold_units=sum(a.craft_sold_units for a in sim.p if a.prof==p),net_sales=sum(a.craft_sales_net for a in sim.p if a.prof==p),sold_opportunity_cost=sum(a.sold_opportunity_cost for a in sim.p if a.prof==p),unsold_units=sum(sum(a.inv[12:]) for a in sim.p if a.prof==p)) for p in range(4)];result['runtime_seconds']=round(time.monotonic()-start,2)
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
