"""Independent checks of persisted V3 output; does not import the simulator."""
import csv,gzip,hashlib,json
from pathlib import Path

out=Path(__file__).resolve().parents[2]/'docs/development/economy-agent-sim-20260926/campaign-v3'
m=json.loads((out/'manifest.json').read_text())
for name,h in m['source_hashes'].items():assert hashlib.sha256((out/name).read_bytes()).hexdigest()==h
expected={(c['name'],s) for c in m['configs'] for s in m['seeds']}
seen=set();trade_count=day_count=0
for path in sorted(out.glob('*/summary.json')):
    r=json.loads(path.read_text());seen.add((r['config']['name'],r['seed']))
    rows=list(csv.DictReader(path.with_name('daily.csv').open()));assert len(rows)==r['config']['days']
    for day,x in enumerate(rows,1):
        assert int(x['day'])==day
        assert int(x['money'])==r['opening_money']+int(x['mint'])-int(x['outflow'])
        for plan in ('free','paid'):
            assert int(x[plan+'_demand'])==sum(int(x[plan+'_'+k]) for k in ('craft_used','event_craft_used','guarantee_used','unmet'))
    gross=fees=count=0;daily_gross={};items={}
    with gzip.open(path.with_name('trades.jsonl.gz'),'rt') as f:
        for line in f:
            t=json.loads(line);assert t['seller']!=t['buyer']
            assert t['quantity']>0 and t['gross']==t['quantity']*t['price']
            assert t['gross']==t['seller_net']+t['fee']
            assert t['buyer_after']==t['buyer_before']-t['gross'] and t['buyer_after']>=0
            assert t['seller_after']==t['seller_before']+t['seller_net']
            gross+=t['gross'];fees+=t['fee'];count+=1
            daily_gross[t['day']]=daily_gross.get(t['day'],0)+t['gross']
            items[t['item']]=items.get(t['item'],0)+t['gross']
    assert gross==r['gross'] and fees==r['outflow']['trade_fee'] and count==r['trade_count']
    for row in rows:assert daily_gross.get(int(row['day']),0)==int(row['p2p_and_project_gross'])
    assert sum(r['mint'].values())==int(rows[-1]['mint'])
    assert sum(r['outflow'].values())==int(rows[-1]['outflow'])
    assert r['end_money']==int(rows[-1]['money'])
    assert sum(int(x['npc_gross']) for x in rows)==r['npc_gross']
    for p in r['professions']:assert 0<=p['first_sale_units']<=p['produced']
    for item in r['items']:assert item['gross']==items.get(item['item'],0)
    assert r['investment_refunded']<=r['investment_paid']
    for e in r['events']:
        assert all(0<=b<=t for b,t in zip(e['bought'],e['target']))
        assert all(w<=a for w,a in zip(e['wins'],e['attempts']))
    day_count+=len(rows);trade_count+=count
assert seen==expected,(len(seen),len(expected))
report=dict(runs=len(seen),days=day_count,trades=trade_count,money_and_transaction_arithmetic=True,
            inventory='Daily internal conservation checks; independent full-inventory replay not available.',
            conclusion='Accounting checks only, not an economic balance certification.')
(out/'independent_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
