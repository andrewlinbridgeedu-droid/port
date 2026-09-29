"""A paired behavioral sensitivity: players choose a cleared floor for missing
recipe materials. Apply a recorded, exact patch to the frozen baseline source in
a temporary directory; never alter baseline results or game source.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, sys, tempfile

OLD='else:f=self.r.randrange(max(1,min(cap,a.floor or 1)))'
NEW='''else:
                    limit=max(1,min(cap,a.floor or 1))
                    recipe=RECIPES[a.prof*4+max(0,self.stage(a))]
                    wanted=[m for m in recipe if m<8 and self.material_floors[m][0]<limit]
                    if wanted:
                        target=max(wanted,key=lambda m:recipe[m]/(a.inv[m]+1))
                        options=[f for f in self.material_floors[target] if f<limit]
                        f=self.r.choice(options)
                    else:f=self.r.randrange(limit)'''
INIT='self.c=c;self.r=random.Random(seed);self.seed=seed;self.trace=trace'
INIT_NEW=INIT+'''
        self.material_floors={m:[i for i,x in enumerate(SOURCE['tower']) if any(m in MAP[d] for d in x['monsters'])] for m in range(8)}'''

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--days',type=int,default=365);p.add_argument('--workers',type=int,default=2);p.add_argument('--seeds',default='101,211,307,401,503');a=p.parse_args()
    root=Path(__file__).parent;source=(root/'model.py').read_text()
    assert source.count(OLD)==1 and source.count(INIT)==1
    modified=source.replace(OLD,NEW).replace(INIT,INIT_NEW)
    out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
    (out/'policy_patch.json').write_text(json.dumps({'baseline_sha256':hashlib.sha256(source.encode()).hexdigest(),'variant_sha256':hashlib.sha256(modified.encode()).hexdigest(),'replacements':[[OLD,NEW],[INIT,INIT_NEW]],'note':'Only replay floor selection changes. Rewards, quantities, wallets, recipes, fees and thresholds unchanged. Not a measured player preference.'},indent=2)+'\n')
    with tempfile.TemporaryDirectory(prefix='mistport-targeted-') as tmp:
        tmp=Path(tmp);(tmp/'model.py').write_text(modified)
        for f in ('source_inputs.json','run.py'):shutil.copyfile(root/f,tmp/f)
        subprocess.run([sys.executable,str(tmp/'run.py'),'--out',str(out),'--days',str(a.days),'--workers',str(a.workers),'--seeds',a.seeds,'--only','baseline,supply_2x,supply_3x,repeat_best'],check=True)
