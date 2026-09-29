"""Compare unchanged cash and per-account 7/14-cycle entitlements offline."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile
from run_followup import build,ROOT,REPO
OUT=REPO/'docs/development/economy-agent-sim-20260926/entitlement'

def variant():
    original,source,edits,market=build()
    extra=[('    repeat_count:int=1','    repeat_count:int=1\n    repeat_window:int=0'),
           ('    advancement_wait:int=0','    advancement_wait:int=0\n    last_repeat_block:int=-1'),
           ("                self.issue_to(a,SOURCE['q_repeat'][q]*self.c.repeat_count,'q_repeat')",
            "                block=(self.day-1)//self.c.repeat_window if self.c.repeat_window else -1\n                if not self.c.repeat_window or a.last_repeat_block!=block:\n                    self.issue_to(a,SOURCE['q_repeat'][q]*self.c.repeat_count,'q_repeat')\n                    a.last_repeat_block=block")]
    for old,new in extra:
        assert source.count(old)==1;source=source.replace(old,new)
    return original,source,edits+extra

if __name__=='__main__':
    original,source,edits=variant()
    OUT.mkdir(parents=True,exist_ok=True)
    assert not (OUT/'manifest.json').exists(),'Do not overwrite evidence'
    (OUT/'policy_patch.json').write_text(json.dumps(dict(baseline_sha256=hashlib.sha256(original.encode()).hexdigest(),variant_sha256=hashlib.sha256(source.encode()).hexdigest(),replacements=edits,note='All accounts mature, no arrivals. One successful Q30 per active cycle assumption. Windows are server-calendar fixed blocks; first active eligible clear pays 105 once, no carry, unused periods expire. Other economy rules unchanged; not a product change. End includes partial final block.'),indent=2)+'\n')
    runner=(ROOT/'run.py').read_text()
    start=runner.index('    base=Config(days=days)');end=runner.index('\ndef one(job):')
    runner=runner[:start]+'''    base=Config(days=days,bundle=4,base_capacity=2,veterans=1,newcomers=0,repeat_strategy='best',repeat_rate=1,expense_stress=True)
    return [replace(base,name='cash_every_clear' if w==0 else 'cash_window'+str(w),repeat_window=w) for w in (0,7,14)]
'''+runner[end:]
    runner=runner.replace("result=sim.summary();", "result=sim.summary();result['end_player_cash']=sum(a.cash for a in sim.p);result['end_npc_cash']=sim.npc;result['active_cycles']=sum(a.active_days for a in sim.p);")
    (OUT/'runner_snapshot.py').write_text(runner)
    with tempfile.TemporaryDirectory(prefix='mistport-entitlement-') as tmp:
        tmp=Path(tmp);(tmp/'model.py').write_text(source);(tmp/'run.py').write_text(runner)
        shutil.copyfile(ROOT/'source_inputs.json',tmp/'source_inputs.json')
        subprocess.run([sys.executable,str(tmp/'run.py'),'--out',str(OUT),'--days','365','--workers','3','--seeds','101,211,307'],check=True)
