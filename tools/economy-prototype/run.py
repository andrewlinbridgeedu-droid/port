import argparse,json,csv
from pathlib import Path
from economy import simulate
p=argparse.ArgumentParser();p.add_argument('--out',required=True);a=p.parse_args()
out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
summary=[]
for days in (180,365):
 for scenario,stress,workers in [('baseline',False,True),('combined',True,True),('no_workers',False,False)]:
  for seed in (1,2,3,4,5):
   result,rows=simulate(seed,days,stress,workers)
   result['scenario']=scenario;summary.append(result)
   if seed==1:
    with (out/f'{scenario}_{days}_daily.csv').open('w') as f:
     w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
