"""Validate lodging candidates using saved actual combat/financial runs."""
from pathlib import Path
from collections import defaultdict, Counter
import json
from analyze_simulation import read,equal_outputs
ROOT=Path(__file__).resolve().parent;SIM=ROOT/'simulation'
base=read(SIM/'housing-adjusted'/'runs.json')
extra=[]
for name in ['housing-basic-no-guests','housing-time45','housing-time120','housing-intermittent']:
    extra += read(SIM/name/'runs.json')
rows=base+extra
assert len(base)==1134 and len(extra)==243 and len(rows)==1377
for r in rows:
    b=r['bankExperiment'];h=r['housingExperiment'];cfg=h['config']
    rent_only='_rent_only_' in b['scenario']['name']
    assert b['minimumCash']>=0 and h['maxStamina']<=100+1e-8 and h['maxReserve']<=20+1e-8
    assert h['reserveUsed']<=h['reserveEarned']+1e-8
    assert h['customerRemaining']+h['customerEscrow']+h['contractGross']==cfg['customerBudget']==400
    assert h['contractNet']==h['contractGross']-h['contractInputs']-h['meetingPaid']
    assert cfg['costs']==[12,16,22,26,42] and cfg['maintenanceCredit']
    if not rent_only:
        assert r['finalMission']==30 and b['advancementSpent']==2400 and len(b['materialDays'])==3
        assert b.get('ritualDay')==(29 if b['scenario']['skipEvery'] else 28)
    if cfg['poorMeeting']: assert h['contracts']==0 and h['contractGross']==0 and h['meetingsFailed']==h['meetings']
    if not cfg['meetings']: assert h['meetings']==h['contracts']==h['meetingPaid']==0
    if not cfg['reserve']: assert h['reserveUsed']==h['reserveEarned']==0
    if not cfg['maintenance']: assert h['repairSaved']==0
    if not cfg['battleRest']: assert h['restBattles']==h['restExtraHP']==0
    assert r['postalJobs']==0
    if not rent_only:
        assert all(e['amount']<0 for e in b['events'] if e['action']=='day_open' and e['day']<=b['ritualDay'])
    opens=[e for e in b['events'] if e['action']=='day_open']
    assert len({e['day'] for e in opens})==len(opens)==len(b['days'])==len(h['days'])
    assert b['livingPaid']==h['housingPaid']==-sum(e['amount'] for e in opens)
    assert h['premiumPaid']==sum(max(0,-e['amount']-12) for e in opens)
    assert h['customerEscrow']>=0 and h['customerRemaining']>=0
    for m in r['milestones']: assert m['day']+1>=max(1,m['mission']-2)
    for v in r['visits']:
        if v['kind']=='tower' and v['won']: assert int(v['target'].split('-')[-1])<=4*(v['day']+1)
    for d in h['days']:
        if d['tier']==4: assert next(e for e in opens if e['day']==d['day'])['mission']>=30
    assert b['riskPrincipal'] in (0,b['scenario']['riskTarget'])
    assert b['riskProfit'] in (0,-b['riskPrincipal'])
    subscriptions={e['action'].removeprefix('subscribe_'):e for e in b['events'] if e['action'].startswith('subscribe_')}
    for e in b['events']:
        if e['action'].startswith('mature_'):
            kind=e['action'].removeprefix('mature_')
            duration=b['scenario']['depositDays']*24 if kind=='deposit' else b['scenario']['riskDays']*24
            assert e['hour']+1e-8>=subscriptions[kind]['hour']+duration, (b['scenario']['name'],kind)
uncached=read(SIM/'housing-uncached'/'runs.json');assert len(uncached)==18
keys=lambda r:(r['bankExperiment']['scenario']['name'],r['policy'],r['profile'],r['startOffset'])
cache={keys(r):r for r in base}
for r in uncached:assert equal_outputs(r,cache[keys(r)]),keys(r)
old=read(SIM/'earning-final'/'runs.json');oldkeys={keys(r):r for r in old}
regression=read(SIM/'bank-regression-housing'/'runs.json');assert len(regression)==18
for r in regression:assert equal_outputs(r,oldkeys[keys(r)]),keys(r)
servers=read(SIM/'server-housing-adjusted'/'results.json')['results'];assert len(servers)==27
for r in servers:
    if r['ext']['name']=='budget_supply_unrepaired': assert not r['L1']
    else:assert r['L1'] and r['L2_strict'] and r['L3']
    assert r['source_audit_pass'] and r['j0_paid']==0 and r['loop_paid_share']==1
    assert r['housing_rules']['prices']==[12,16,22,26,42]
    assert r['housing_rules']['customer_account']=='general_business_cash'
    assert r['housing']['rooms_peak']['1']<=1200 and r['housing']['rooms_peak']['2']<=600
    assert r['housing']['rooms_peak']['3']<=200 and r['housing']['rooms_peak']['4']<=80
power=read(SIM/'housing-power.json');assert len(power)==36
modes=['basic','budget','greedy','arcade','canal','loft','highland','basic_no_meeting','no_reserve','no_buff','no_maintenance','no_meeting','meeting_failed','rent_only','split']
def mode(r):
    name=r['bankExperiment']['scenario']['name']
    return next(x for x in sorted(modes,key=len,reverse=True) if name.startswith('adjusted_'+x+'_'))
g=defaultdict(list)
for r in rows:g[mode(r)].append(r)
def stats(rs):
    days=[r['bankExperiment']['ritualDay'] for r in rs if r['bankExperiment'].get('ritualDay')]
    return dict(n=len(rs),completed=len(days),ritual_days=sorted(set(days)),aid_days=sum(r['bankExperiment']['reliefDays'] for r in rs),
        chapter_cash=[min(r['housingExperiment']['chapterCash'] for r in rs),max(r['housingExperiment']['chapterCash'] for r in rs)],
        actual_risk=Counter(r['bankExperiment']['riskPrincipal'] for r in rs),
        premium=[min(r['housingExperiment']['premiumPaid'] for r in rs),max(r['housingExperiment']['premiumPaid'] for r in rs)])
draft=read(SIM/'housing-draft'/'runs.json');assert len(draft)==243
summary=dict(checks=dict(main_runs=1134,ordinary_no_guest_runs=81,timing_runs=162,final_runs=1377,
    positive_completed=sum(bool(r['bankExperiment'].get('ritualDay')) for r in rows if '_rent_only_' not in r['bankExperiment']['scenario']['name']),
    positive_runs=sum('_rent_only_' not in r['bankExperiment']['scenario']['name'] for r in rows),
    final_completed=sum(bool(r['bankExperiment'].get('ritualDay')) for r in rows),negative_rent_only_failures=sum(not r['bankExperiment'].get('ritualDay') for r in rows),
    cached_vs_uncached=18,legacy_bank_regressions=18,server_runs=27,server_days=27*365,power_comparisons=36),
    modes={k:stats(v) for k,v in g.items()},draft=dict(n=243,completed=sum(bool(r['bankExperiment'].get('ritualDay')) for r in draft)),
    representative=[dict(mode=mode(r),policy=r['policy'],chapter_cash=r['housingExperiment']['chapterCash'],chapter_living=r['housingExperiment']['chapterLiving'],
        day42_cash=r['copper'],housing=r['housingExperiment'],bank=r['bankExperiment']) for r in base+extra[:81] if r['profile']=='medium' and r['startOffset']==0 and r['bankExperiment']['scenario']['name'].endswith('_none')],servers=servers,power=power)
(SIM/'housing-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary['checks'],ensure_ascii=False))
