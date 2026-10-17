"""Latest user decision: advancement requires earned material money; investment stays optional."""
import json
from pathlib import Path
from analyze_simulation import read, equal_outputs, groups, stats
ROOT = Path(__file__).resolve().parent
SIM = ROOT/'simulation'
rows = read(SIM/'earning-final'/'runs.json')
assert len(rows) == 486
for r in rows:
    b = r['bankExperiment']; s = b['scenario']
    assert r['finalMission'] == 30 and b['advancementSpent'] == 2400
    assert b['ritualDay'] == (29 if s['skipEvery'] else 28)
    assert b['remainingAdvancementCost'] == 0 and len(b['materialDays']) == 3
    assert s['advancementPrices'] == [500,650,950,300] and not s['cashRecovery']
    assert r['copperBySource'].get('postal',0) == 0 and r['postalJobs'] == 0
    assert b['minimumCash'] >= 0 and b['reliefDays'] == 0
    assert b['livingPaid'] == len(b['days'])*12
    assert b['outstandingPrincipal'] == 0
    assert b['riskPrincipal'] in (0,s['riskTarget'])
    assert b['riskProfit'] == b['riskPrincipal'] * s['riskReturnPercent']//100-b['riskPrincipal']
    assert b['depositProfit'] == (0 if s['forceEarlyExit'] else s['deposit']//20*4)
    if s['unsafeInvestment']: assert b['riskPrincipal']==160 and b['riskProfit']==-160
    assert len([e for e in b['events'] if e['action']=='ritual'])==1
    assert sum(-e['amount'] for e in b['events'] if e['action'].startswith('material_') or e['action']=='ritual')==2400
    for m in r['milestones']: assert m['day']+1 >= max(1,m['mission']-2)
    for v in r['visits']:
        if v['kind']=='tower' and v['won']: assert int(v['target'].split('-')[-1]) <= 4*(v['day']+1)
    for e in b['events']:
        if e['action']=='extra_failure_cost': assert e['amount']==-60
        if e['action']=='subscribe_risk': assert e['principalLocked'] <= (160 if e['mission']>=16 else 100)
    opens=[e for e in b['events'] if e['action']=='day_open']
    assert len({e['day'] for e in opens})==len(opens)==len(b['days'])
    assert all(e['amount']==-12 for e in opens)
uncached = read(SIM/'earning-uncached'/'runs.json')
assert len(uncached)==18
matching={(r['bankExperiment']['scenario']['name'],r['policy'],r['profile'],r['startOffset']):r for r in rows}
for r in uncached:
    key=(r['bankExperiment']['scenario']['name'],r['policy'],r['profile'],r['startOffset'])
    assert equal_outputs(r,matching[key]), key
server_initial=read(SIM/'server-earning'/'results.json')
controls=read(SIM/'server-earning-controls'/'results.json')['results']
server=[r for r in server_initial['results'] if r['ext']['name']!='combined_loss_and_supply']+controls
assert len(server)==24
for r in server:
    assert r['candidate_rules']['materials']==[[17,500],[20,650],[23,950],[30,300]]
    assert not r['candidate_rules']['cash_recovery'] and r['j0_paid']==0
    name=r['ext']['name']
    if name=='negative_unbacked_coupon': assert not r['source_audit_pass']
    elif name=='supply_half_unrepaired': assert not r['L1'] and r['source_audit_pass']
    else: assert r['L1'] and r['L2_strict'] and r['L3'] and r['source_audit_pass']
    assert r['loop_paid_share']==1.
# Parameter sweeps share the same no-cash-aid and stage-saving rules.
sweeps={}
for total in [2200,2400,2600,3200]:
    rr=read(SIM/f'earning{total}-pilot'/'runs.json')
    sweeps[str(total)]=dict(n=len(rr),completed=sum(bool(r['bankExperiment'].get('ritualDay')) for r in rr))
assert sweeps['2400']['completed']==27 and sweeps['2600']['completed']==25 and sweeps['3200']['completed']==0
summary=dict(rules=dict(materials=[500,650,950],ritual=300,total=2400,minimum_nonstory_income=556,cash_recovery=False),
    checks=dict(campaign_runs=486,completed=486,cached_vs_uncached=18,server_final_runs=24,server_final_days=24*365,server_additional_budget_comparison=3),
    scenarios={k:stats(v) for k,v in groups(rows).items()},price_sweeps=sweeps,
    representative=[dict(scenario=r['bankExperiment']['scenario']['name'],policy=r['policy'],cash=r['copper'],relics=len(r['passives']),sources=r['copperBySource'],risk=r['bankExperiment']['riskPrincipal']) for r in rows if r['startOffset']==0 and r['profile']=='medium'],
    server=server)
(SIM/'earning-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary['checks'],ensure_ascii=False))
