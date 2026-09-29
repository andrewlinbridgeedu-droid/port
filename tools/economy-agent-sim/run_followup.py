"""Expense and mature-server issuance stress; does not modify baseline/runtime."""
from pathlib import Path
import hashlib, json, re, shutil, subprocess, sys, tempfile
from run_shopping import REPLACEMENTS, PROFIT_OLD, PROFIT_NEW

ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[1]
OUT=REPO/'docs/development/economy-agent-sim-20260926/followup'

def build():
    source=(ROOT/'model.py').read_text()
    market=REPO/'mistport-ios/MistportCombatCore/Sources/MistportCombatCore/AdvancementMaterialMarket.swift'
    offers=[(int(q),int(p)) for q,p in re.findall(r'unlockMission: (\d+), price: (\d+)',market.read_text())]
    assert offers==[(17,260),(20,340),(23,480)]
    edits=REPLACEMENTS+[(PROFIT_OLD,PROFIT_NEW),
        ('    repeat_rate:float=.25','    expense_stress:bool=False\n    repeat_count:int=1\n    repeat_rate:float=.25'),
        ('    battles:int=0','    battles:int=0\n    advancement:set=field(default_factory=set)\n    advancement_wait:int=0'),
        ('                a.cash=int(self.r.lognormvariate', '                a.advancement={17,20,23} # assumed already owned by initialized veterans\n                a.cash=int(self.r.lognormvariate'),
        ("                self.issue_to(a,SOURCE['q_repeat'][q],'q_repeat')", "                self.issue_to(a,SOURCE['q_repeat'][q]*self.c.repeat_count,'q_repeat')"),
        ('            for j,b in enumerate(SOURCE[\'bounty\']):',
         '            if self.c.expense_stress:\n                for unlock,price in '+repr(offers)+':\n                    if a.q>=unlock and unlock not in a.advancement:\n                        if a.cash>=price:\n                            self.retire(a,price,\'advancement\');a.advancement.add(unlock)\n                        else:a.advancement_wait+=1\n            for j,b in enumerate(SOURCE[\'bounty\']):')]
    modified=source
    for old,new in edits:
        assert modified.count(old)==1,old
        modified=modified.replace(old,new)
    return source,modified,edits,market

if __name__=='__main__':
    source,modified,edits,market=build()
    OUT.mkdir(parents=True,exist_ok=True)
    assert not (OUT/'manifest.json').exists(),'Do not overwrite a completed experiment'
    (OUT/'policy_patch.json').write_text(json.dumps(dict(baseline_sha256=hashlib.sha256(source.encode()).hexdigest(),variant_sha256=hashlib.sha256(modified.encode()).hexdigest(),replacements=edits,advancement_source_sha256=hashlib.sha256(market.read_bytes()).hexdigest(),limitations='Expense stress assumes all non-veterans buy all three once, no alternate grants; no story gate or progression proof. Mature repeat 3/10 multiply copper only, without extra time/combat/repair/material cost, therefore gross issuance stress not gameplay prediction. Baseline recipe placeholders remain.'),indent=2)+'\n')
    runner=(ROOT/'run.py').read_text()
    start=runner.index('    base=Config(days=days)');end=runner.index('\ndef one(job):')
    grid='''    base=Config(days=days,bundle=4,base_capacity=2,expense_stress=True)
    return [replace(base,name='expense_supply2'),
            *[replace(base,name='mature_repeat'+str(n),veterans=1,newcomers=0,repeat_strategy='best',repeat_rate=1,repeat_count=n) for n in (1,3,10)]]
'''
    runner=runner[:start]+grid+runner[end:]
    runner=runner.replace("result=sim.summary();", "result=sim.summary();result['advancement_paid_accounts']=sum(bool(a.advancement) and a.q<31 for a in sim.p);result['advancement_wait_player_item_cycles']=sum(a.advancement_wait for a in sim.p);result['advancement_unpaid_eligible_items']=sum(q<=a.q and q not in a.advancement for a in sim.p for q in (17,20,23));")
    # Owned accounts include initialized veterans; name this correctly.
    runner=runner.replace('advancement_paid_accounts','advancement_owned_accounts')
    (OUT/'runner_snapshot.py').write_text(runner)
    with tempfile.TemporaryDirectory(prefix='mistport-economy-followup-') as tmp:
        tmp=Path(tmp);(tmp/'model.py').write_text(modified);(tmp/'run.py').write_text(runner)
        shutil.copyfile(ROOT/'source_inputs.json',tmp/'source_inputs.json')
        subprocess.run([sys.executable,str(tmp/'run.py'),'--out',str(OUT),'--days','365','--workers','3','--seeds','101,211,307'],check=True)
