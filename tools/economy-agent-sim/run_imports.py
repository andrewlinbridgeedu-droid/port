"""Funded finite imports and batch leather experiment; no runtime changes."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile
from run_entitlement import variant as entitlement_variant,ROOT,REPO
OUT=REPO/'docs/development/economy-agent-sim-20260926/imports'

def variant():
    original,source,edits=entitlement_variant()
    extra=[
        ('    repeat_window:int=0','    repeat_window:int=0\n    import_cost:int=12\n    retail_margin:int=2\n    craft_fee:int=2\n    leather_batch:int=1'),
        ('    last_repeat_block:int=-1','    last_repeat_block:int=-1\n    unit_basis:list=field(default_factory=lambda:[0.]*16)\n    craft_sales_net:int=0\n    craft_sold_units:int=0\n    sold_opportunity_cost:float=0.'),
        ('        self.c=c;self.r=random.Random(seed);self.seed=seed;self.trace=trace',
         '        self.c=c;self.r=random.Random(seed);self.seed=seed;self.trace=trace\n        P0[8:12]=[c.import_cost+c.retail_margin]*4'),
        ('            b.cash+=gross-fee;b.inv[item]-=qty;b.sales+=gross-fee',
         '            b.cash+=gross-fee;b.inv[item]-=qty;b.sales+=gross-fee\n            if item>=12:\n                b.craft_sales_net+=gross-fee;b.craft_sold_units+=qty\n                b.sold_opportunity_cost+=qty*b.unit_basis[item-12]'),
        ('        if a:a.cash-=gross;a.inv[item]+=qty',
         '        if a:\n            if item>=12:a.unit_basis[item-12]=(a.inv[item]*a.unit_basis[item-12]+gross)/(a.inv[item]+qty)\n            a.cash-=gross;a.inv[item]+=qty'),
        ('enumerate(zip((24,18,15,70),(5,7,9,4)))','enumerate(zip((24,18,15,70),(self.c.import_cost,)*4))'),
        ('self.npc[0]-=qty*cost;self.npc[1]+=qty*cost',"self.npc[0]-=qty*cost;self.sinks['external_import']+=qty*cost"),
        ('            if a.cash<1 or a.inv[item]>=8 or any(a.inv[k]<q for k,q in recipe.items()):continue',
         '            output=self.c.leather_batch if a.prof==1 else 1\n            if a.cash<self.c.craft_fee or a.inv[item]+output>8 or any(a.inv[k]<q for k,q in recipe.items()):continue'),
        ('            opportunity_cost=1+sum(', '            opportunity_cost=self.c.craft_fee+sum('),
        ('self.ref[item]*(1-self.c.fee_bps/10000)<opportunity_cost','output*self.ref[item]*(1-self.c.fee_bps/10000)<opportunity_cost'),
        ("            a.inv[item]+=1;self.created[item]+=1;a.crafts+=1;self.retire(a,1,'craft')",
         "            a.unit_basis[item-12]=(a.inv[item]*a.unit_basis[item-12]+opportunity_cost)/(a.inv[item]+output)\n            a.inv[item]+=output;self.created[item]+=output;a.crafts+=1;self.retire(a,self.c.craft_fee,'craft')")]
    for old,new in extra:
        assert source.count(old)==1,(old,source.count(old));source=source.replace(old,new)
    return original,source,edits+extra

if __name__=='__main__':
    original,source,edits=variant();OUT.mkdir(parents=True,exist_ok=True)
    assert not (OUT/'manifest.json').exists(),'Do not overwrite evidence'
    (OUT/'policy_patch.json').write_text(json.dumps(dict(baseline_sha256=hashlib.sha256(original.encode()).hexdigest(),variant_sha256=hashlib.sha256(source.encode()).hexdigest(),replacements=edits,note='Import cash leaves server when finite merchant purchases actual stock, retail = import cost + 2 retained merchant margin. Existing initial stock remains opening stock, not charged again. Craft fee 2 replaces 1. Leather batch output 1 or 6, shelf cap 8, proficiency once per batch. Realized product contribution uses production-time raw quote opportunity cost plus retail bases and craft fee, weighted-average unit basis; excludes training/recipe fees and unsold write-downs. No actual gameplay timing, newcomers or other repeat cash.'),indent=2)+'\n')
    runner=(ROOT/'run.py').read_text();start=runner.index('    base=Config(days=days)');end=runner.index('\ndef one(job):')
    runner=runner[:start]+'''    base=Config(days=days,bundle=4,base_capacity=2,veterans=1,newcomers=0,repeat_strategy='best',repeat_rate=1,expense_stress=True)
    return [replace(base,name=f'w{w}_import{cost}_batch{batch}',repeat_window=w,import_cost=cost,leather_batch=batch) for w,cost,batch in ((7,12,1),(7,12,6),(14,12,6),(14,6,6))]
'''+runner[end:]
    runner=runner.replace('result=sim.summary();',"result=sim.summary();result['end_player_cash']=sum(a.cash for a in sim.p);result['end_npc_cash']=sim.npc;result['professions']=[dict(profession=p,craft_batches=sum(a.crafts for a in sim.p if a.prof==p),sold_units=sum(a.craft_sold_units for a in sim.p if a.prof==p),net_sales=sum(a.craft_sales_net for a in sim.p if a.prof==p),sold_opportunity_cost=sum(a.sold_opportunity_cost for a in sim.p if a.prof==p),unsold_units=sum(sum(a.inv[12:]) for a in sim.p if a.prof==p)) for p in range(4)];")
    (OUT/'runner_snapshot.py').write_text(runner)
    with tempfile.TemporaryDirectory(prefix='mistport-imports-') as tmp:
        tmp=Path(tmp);(tmp/'model.py').write_text(source);(tmp/'run.py').write_text(runner)
        shutil.copyfile(ROOT/'source_inputs.json',tmp/'source_inputs.json')
        subprocess.run([sys.executable,str(tmp/'run.py'),'--out',str(OUT),'--days','365','--workers','3','--seeds','101,211,307'],check=True)
