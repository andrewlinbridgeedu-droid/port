"""Deterministic state/gate property checks. No balance or Unity claims."""
from collections import Counter
from itertools import product
from pathlib import Path
import argparse, json, random
from evidence_gate import PassiveEvidenceGate
from validate_s9 import allocation_path
from talent_core import TalentSession, TalentError, validate, NODE_IDS

def run_properties():
    allocations=Counter()
    for vector in product(range(6),repeat=6):
        try:
            allocation_path(list(vector));old_valid=True
        except ValueError:old_valid=False
        try:
            validate({f'T{i+1}':v for i,v in enumerate(vector)},30);new_valid=True
        except TalentError:new_valid=False
        assert old_valid==new_valid,vector
        if new_valid:allocations[sum(vector)]+=1
    rng=random.Random(20260910)
    gate=PassiveEvidenceGate();tick=0;live=[];last_by_enemy={};grants=0
    for hit in range(10000):
        tick+=rng.randrange(0,36)
        enemy=rng.randrange(8)
        answer=gate.attempt(tick,enemy,hit,eligible=rng.random()>.08,has_capacity=rng.random()>.1)
        if answer.accepted:
            assert tick-last_by_enemy.get(enemy,-10000)>=100
            last_by_enemy[enemy]=tick;live.append(tick);grants+=1
        live=[value for value in live if value>tick-100]
        assert len(live)<=2
    session=TalentSession({},30)
    accepted_edits=0;rejected_edits=0
    for _ in range(3000):
        node=rng.choice(NODE_IDS);choice=rng.randrange(10)
        before=dict(session.draft)
        try:
            if choice<6:session.add(node)
            elif choice<9:
                plan=session.preview_remove(node)
                before_total=sum(session.draft.values())
                session.confirm_remove(plan)
                assert before_total-sum(session.draft.values())==plan.total_refund
            else:session.reset(rng.choice(('T','P','S')))
            accepted_edits+=1
        except TalentError:
            assert session.draft==before
            rejected_edits+=1
        validate(session.draft,30)
        assert 0<=30-sum(session.draft.values())<=30
    return {'scope':'reference state/gate properties only',
            'allocation_vectors_checked':46656,'same_as_v01':True,
            'valid_vectors':sum(allocations.values()),
            'by_points':dict(sorted(allocations.items())),
            'gate_events_checked':10000,'gate_grants':grants,
            'gate_global_window_and_per_enemy_invariant':True,
            'draft_operations_checked':3000,'accepted_edits':accepted_edits,
            'rejected_edits_without_mutation':rejected_edits,'seed':20260910}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outdir',type=Path,default=Path(__file__).parent/'results')
    args=parser.parse_args();args.outdir.mkdir(parents=True,exist_ok=True)
    result=run_properties()
    (args.outdir/'property_checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
