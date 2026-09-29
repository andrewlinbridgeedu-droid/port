"""Correct restrictive single-SKU shopping; optionally stop loss-making mature
crafting. Preserve the original run as an explicitly labeled behavioral control.
"""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,sys,tempfile
REPLACEMENTS=[(
'''item=min([k for k in range(24,28) if k in available] or [24],key=lambda k:self.ref[k])
                ceiling=math.ceil(30*wealth)
                requests[item].append((i,a.need,ceiling))''',
'''ceiling=math.ceil(30*wealth)
                for item in range(24,28):
                    requests[item].append((i,a.need,ceiling))'''),(
'''for item in sorted(keys):''',
'''for item in sorted(keys,key=lambda k:(1,self.ref[k],k) if k>=24 else (0,k,k)):'''),(
'''for buyer,qty,ceiling in bids:
                while qty''',
'''for buyer,qty,ceiling in bids:
                if item>=24 and buyer<self.c.n:
                    owner=self.p[buyer]
                    qty=min(qty,max(0,owner.need-sum(owner.inv[24:28])))
                while qty''')]
# Demand for substitutes must also be de-duplicated when computing quote signals:
# unmet orders are not four independent potion needs.
REPLACEMENTS.append((
'''offers=[];want=sum(q for _,q,_ in bids)''',
'''offers=[]
            want=sum(min(q,max(0,self.p[i].need-sum(self.p[i].inv[24:28]))) if item>=24 and i<self.c.n else q for i,q,_ in bids)'''))
PROFIT_OLD='''if a.cash<1 or a.inv[item]>=8 or any(a.inv[k]<q for k,q in recipe.items()):continue'''
PROFIT_NEW=PROFIT_OLD+'''
            opportunity_cost=1+sum((P0[k] if k>=8 else self.ref[k])*q for k,q in recipe.items())
            self_use=(a.prof==3 and a.need>sum(a.inv[24:28])) or (a.prof==0 and a.gear[0]<t) or (a.prof==2 and a.gear[1]<t)
            training=a.skill-STAGES[t]<30
            if not training and not self_use and self.ref[item]*(1-self.c.fee_bps/10000)<opportunity_cost:continue'''
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--profit',action='store_true');p.add_argument('--workers',type=int,default=2);p.add_argument('--days',type=int,default=365);p.add_argument('--seeds',default='101,211,307,401,503');a=p.parse_args()
    root=Path(__file__).parent;source=(root/'model.py').read_text();modified=source
    edits=REPLACEMENTS+([(PROFIT_OLD,PROFIT_NEW)] if a.profit else [])
    for old,new in edits:
        assert modified.count(old)==1,(old,modified.count(old));modified=modified.replace(old,new)
    out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True)
    (out/'policy_patch.json').write_text(json.dumps(dict(baseline_sha256=hashlib.sha256(source.encode()).hexdigest(),variant_sha256=hashlib.sha256(modified.encode()).hexdigest(),replacements=edits,note='All potion tiers substitute for one optional battle use in this simplified model. Orders cannot overbuy; materials and monetary rules unchanged. Profit option suppresses mature loss-making crafts, not training or self-use.'),indent=2)+'\n')
    with tempfile.TemporaryDirectory(prefix='mistport-shopping-') as tmp:
        tmp=Path(tmp);(tmp/'model.py').write_text(modified)
        for f in ('source_inputs.json','run.py'):shutil.copyfile(root/f,tmp/f)
        subprocess.run([sys.executable,str(tmp/'run.py'),'--out',str(out),'--days',str(a.days),'--workers',str(a.workers),'--seeds',a.seeds,'--only','baseline,supply_2x,supply_3x,repeat_best'],check=True)
