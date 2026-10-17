"""Validate and summarize the saved experiment; accepts compressed raw runs as well."""
import gzip
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SIM = ROOT / 'simulation'

def read(path):
    if path.exists(): return json.loads(path.read_text())
    with gzip.open(str(path) + '.gz', 'rt') as f: return json.load(f)

def groups(rows):
    result = defaultdict(list)
    for r in rows: result[r['bankExperiment']['scenario']['name']].append(r)
    return result

def stats(rows):
    b = [r['bankExperiment'] for r in rows]
    days = [x['ritualDay'] for x in b if x.get('ritualDay')]
    return dict(n=len(rows), story_finished=sum(r['finalMission']==30 for r in rows),
        ritual_finished=len(days), ritual_days=[min(days), max(days)] if days else None,
        cash=[min(r['copper'] for r in rows),max(r['copper'] for r in rows)],
        risk_subscribed=sum(x['riskPrincipal']>0 for x in b),
        actual_risk_principal=sorted(set(x['riskPrincipal'] for x in b)),
        risk_profit=sorted(set(x['riskProfit'] for x in b)),
        deposit_profit=sorted(set(x['depositProfit'] for x in b)),
        relief_days=sum(x['reliefDays'] for x in b),
        max_active_day_minutes=max(max(r['minutesByDay']) for r in rows))

def equal_outputs(a, b):
    # Dictionary reduction order changes only floating point summation round-off.
    # Copper, dates, outcomes, receipts and all integer quantities remain exact.
    if isinstance(a, float) and isinstance(b, (int,float)):
        return math.isclose(a, b, rel_tol=0, abs_tol=1e-8)
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys()==b.keys() and all(equal_outputs(a[k],b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a)==len(b) and all(equal_outputs(x,y) for x,y in zip(a,b))
    return a==b

def main():
    original, final = [read(SIM / v / 'runs.json') for v in ['original','final']]
    assert len(original) == len(final) == 486
    # Real qualification, paid food and completed risk loss, not just a Q30 flag.
    for r in final:
        b = r['bankExperiment']; s = b['scenario']
        assert r['finalMission'] == 30 and b.get('ritualDay') and b['advancementSpent'] == 1360
        assert b['remainingAdvancementCost'] == 0 and len(b['materialDays']) == 3
        assert b['reliefDays'] == 0 and b['minimumCash'] >= 0
        if b['outstandingPrincipal']:
            assert s['name']=='final_risk80_delay' and b['outstandingPrincipal']==80 and b['riskProfit']==0
        assert b['livingPaid'] == len(b['days']) * 12
        assert b['riskPrincipal'] == s['riskTarget']
        if not b['outstandingPrincipal']:
            assert b['riskProfit'] == s['riskTarget'] * s['riskReturnPercent'] // 100 - s['riskTarget']
        assert b['depositProfit'] == (0 if s['forceEarlyExit'] else s['deposit'] // 20 * 4)
        assert b['earlyRedemptions'] == int(s['forceEarlyExit'])
        assert b['ritualDay'] == (29 if s['skipEvery'] else 28)
        assert len([e for e in b['events'] if e['action']=='ritual']) == 1
        for m in r['milestones']:
            assert m['day']+1 >= max(1, m['mission']-2)
        for v in r['visits']:
            if v['kind']=='tower' and v['won']:
                assert int(v['target'].split('-')[-1]) <= 4*(v['day']+1)
        for e in b['events']:
            if e['action']=='extra_failure_cost': assert e['amount']==-60
            if e['action']=='subscribe_risk':
                assert e['principalLocked'] <= (160 if e['mission']>=16 else 100)
        opens=[e for e in b['events'] if e['action']=='day_open']
        assert len({e['day'] for e in opens}) == len(opens) == len(b['days'])
        assert all(e['amount']==-12 for e in opens)
    uncached = read(SIM/'uncached'/'runs.json')
    assert len(uncached)==18
    matching = {(r['bankExperiment']['scenario']['name'],r['policy'],r['profile'],r['startOffset']):r for r in final}
    for r in uncached:
        k=(r['bankExperiment']['scenario']['name'],r['policy'],r['profile'],r['startOffset'])
        assert equal_outputs(r, matching[k]), f'cache changed results: {k}'
    server=[]
    for name in ['server-final','server-adjusted']:
        server += read(SIM/name/'results.json')['results']
    assert len(server)==45
    for r in server:
        if r['ext']['name'] in ['loss_fund1680k','repair2000','combined_loss_and_supply']:
            assert r['L1'] and r['L2_strict'] and r['L3'] and r['source_audit_pass']
        if r['ext']['name']=='negative_unbacked_coupon': assert not r['source_audit_pass']
        if r['ext']['name']=='risk80_total_loss': assert not r['L3']
    summary=dict(original={k:stats(g) for k,g in groups(original).items()},
                 final={k:stats(g) for k,g in groups(final).items()},
                 checks=dict(campaign_pairs=486, final_completed=486, cached_vs_uncached_identical=18,
                     server_runs=45, server_days_checked=45*365, money_identity_errors=0),
                 representative=[{k:r[k] for k in ['policy','profile','copper','copperBySource','repairCopper','salvesUsed','passives']}|
                     {'scenario':r['bankExperiment']['scenario']['name'], 'days':r['bankExperiment']['ritualDay'],
                      'risk_day':r['bankExperiment'].get('firstRiskDay')}
                     for r in final if r['startOffset']==0 and r['profile']=='medium' and
                     r['bankExperiment']['scenario']['name'] in ['final_none','final_deposit60','final_risk80_profit','final_risk80_total_loss','final_risk160_total_loss']])
    (SIM/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary['checks'],ensure_ascii=False))

if __name__=='__main__':main()
