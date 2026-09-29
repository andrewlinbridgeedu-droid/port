"""Independent audit of stored outputs, without importing the simulation."""
import csv,json,sys,hashlib
from pathlib import Path
out=Path(sys.argv[1]);manifest=json.loads((out/'manifest.json').read_text())
source=Path(__file__).with_name('model.py').read_text()
patch=out/'policy_patch.json'
if patch.exists():
    policy=json.loads(patch.read_text())
    assert hashlib.sha256(source.encode()).hexdigest()==policy['baseline_sha256']
    for old,new in policy['replacements']:
        assert source.count(old)==1
        source=source.replace(old,new)
    assert hashlib.sha256(source.encode()).hexdigest()==policy['variant_sha256']
assert hashlib.sha256(source.encode()).hexdigest()==manifest['source_hashes']['model.py']
expected={(c['name'],s) for c in manifest['configs'] for s in manifest['seeds']}
seen=set();days=trades=0
for path in sorted(out.glob('*/summary.json')):
    r=json.loads(path.read_text());seen.add((r['config']['name'],r['seed']))
    rows=list(csv.DictReader(path.with_name('daily.csv').open()))
    assert len(rows)==r['config']['days']
    last_issue=last_sink=0
    for i,x in enumerate(rows,1):
        assert int(x['day'])==i
        issue,sink=int(x['issuance']),int(x['sink'])
        assert issue>=last_issue and sink>=last_sink
        assert int(x['money'])==r['opening_money']+issue-sink
        assert 0<=int(x['free_met'])<=int(x['free_need'])
        assert 0<=int(x['paid_met'])<=int(x['paid_need'])
        last_issue,last_sink=issue,sink
    assert sum(int(x['gross']) for x in rows)==r['gross']
    assert sum(r['issuance'].values())==last_issue
    assert sum(r['sinks'].values())==last_sink
    assert sum(x[0] for x in r['flows'].values())==r['gross']
    assert sum(r['wealth_flows'].values())==r['gross']
    assert r['issuance'].get('q_first',0)<=r['config']['n']*2280
    assert r['issuance'].get('tower_first',0)<=r['config']['n']*1700
    assert r['issuance'].get('bounty_first',0)<=r['config']['n']*1060
    for e in r['events']:
        if 'spent' in e:assert 0<=e['spent']<=e['budget']
    trace=path.with_name('trade_examples.json')
    if trace.exists():
        for x in json.loads(trace.read_text()):
            assert x['buyer']!=x['seller'] and x['buyer_after']>=0
            assert x['gross']==x['quantity']*x['unit_price']
            assert x['gross']==x['fee']+x['seller_net']
    days+=len(rows);trades+=r['trades']
assert seen==expected,(len(seen),len(expected))
report=dict(runs=len(seen),daily_rows=days,trades_reported=trades,stored_money_and_gross_reconciled=True,inventory_note='Inventory conservation asserted inside simulator each day; full inventories not exported independently.')
(out/'independent_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
