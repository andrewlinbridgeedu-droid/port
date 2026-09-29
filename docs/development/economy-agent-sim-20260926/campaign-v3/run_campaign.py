"""Run frozen-price V3 feasibility candidates, retain every failure."""
from concurrent.futures import ProcessPoolExecutor,as_completed
from dataclasses import replace,asdict
from pathlib import Path
import csv,gzip,hashlib,json,time
from campaign_model import Config,Sim

ROOT=Path(__file__).resolve().parent
OUT=ROOT.parents[1]/'docs/development/economy-agent-sim-20260926/campaign-v3'

def one(job):
    c,seed=job;started=time.monotonic();s=Sim(c,seed);r=s.run()
    p=OUT/f'{c.name}-{seed}';p.mkdir()
    with (p/'daily.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=list(s.daily[0]));w.writeheader();w.writerows(s.daily)
    with gzip.open(p/'trades.jsonl.gz','wt') as f:
        for row in s.trades:f.write(json.dumps(row,separators=(',',':'))+'\n')
    r['runtime_seconds']=time.monotonic()-started
    (p/'summary.json').write_text(json.dumps(r,indent=2)+'\n')
    return c.name,seed,r['runtime_seconds'],r['metrics']

if __name__=='__main__':
    OUT.mkdir(exist_ok=True)
    assert not (OUT/'manifest.json').exists(),'Never overwrite completed or partial evidence.'
    configs=[]
    for window in (0,7,14):
        for war in (False,True):configs.append(Config(name=f'w{window}_'+('war_prep7' if war else 'control'),cash_window=window,war=war))
    configs.extend([Config(name='w14_war_mint',cash_window=14,war=True,procurement_mint=True),
                    Config(name='w14_war_no_prep',cash_window=14,war=True,preparation=0),
                    Config(name='w14_war_70_30',cash_window=14,war=True,faction_share=.7)])
    seeds=(101,211,307)
    sources={}
    for name in ('campaign_model.py','salve_policy.py','source_inputs.json','run_campaign.py'):
        b=(ROOT/name).read_bytes();sources[name]=hashlib.sha256(b).hexdigest();(OUT/name).write_bytes(b)
    (OUT/'manifest.json').write_text(json.dumps(dict(configs=[asdict(c) for c in configs],seeds=seeds,source_hashes=sources,
        note='27 new mature-only fixed-price feasibility runs; not CPI, full narrative or investment return validation.'),indent=2)+'\n')
    with ProcessPoolExecutor(max_workers=3) as pool:
        fs=[pool.submit(one,(c,seed)) for c in configs for seed in seeds]
        for i,f in enumerate(as_completed(fs),1):
            name,seed,seconds,metrics=f.result()
            print(i,27,name,seed,round(seconds,2),json.dumps(metrics),flush=True)
