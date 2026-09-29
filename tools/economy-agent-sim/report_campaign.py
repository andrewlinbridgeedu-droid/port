"""Report all V3 scenarios, no selectively hidden failures."""
import csv,json,statistics
from pathlib import Path
out=Path(__file__).resolve().parents[2]/'docs/development/economy-agent-sim-20260926/campaign-v3'
r=[json.loads(p.read_text()) for p in out.glob('*/summary.json')]
m=json.loads((out/'manifest.json').read_text());assert len(r)==len(m['configs'])*len(m['seeds'])
lines=['# V3 production chain and campaign feasibility','',
'27 runs: 2000 mature accounts, 365 cycles, seeds 101/211/307. All values below are model outputs, not player telemetry.',
'Fixed prices deliberately isolate quantity and wallet feasibility. No inflation, price-stability or market-clearing-price verdict.',
'No changes to actual rewards, saves or runtime. Two campaigns start on cycles 120 and 240; normal days include postwar days.',
'', '|Scenario|Annual mint|Retire + import outflow|Net money increase|Trade gross + base NPC sales|',
'|---|---:|---:|---:|---:|']
groups=[]
for n in [c['name'] for c in m['configs']]:
    a=[x for x in r if x['config']['name']==n];groups.append((n,a))
    avg=lambda f:statistics.mean(f(x) for x in a)
    mint=avg(lambda x:sum(x['mint'].values()));ret=avg(lambda x:sum(x['outflow'].values()))
    lines.append(f'|{n}|{mint:,.0f}|{ret:,.0f}|{mint-ret:,.0f}|{avg(lambda x:x["gross"]+x["npc_gross"]):,.0f}|')
lines+=['','## Medicine by phase (free accounts)','', '|Scenario|Phase|Craft fill incl. delivered field medicine|System guarantee fill|Total fill|','|---|---|---:|---:|---:|']
for n,a in groups:
    for phase in ('normal','preparation','action'):
        vals=[x['metrics'][phase]['free'] for x in a if phase in x['metrics']]
        if not vals:continue
        avg=lambda k:statistics.mean(v[k] for v in vals)
        lines.append(f'|{n}|{phase}|{avg("craft_fill"):.2%}|{avg("guarantee_fill"):.2%}|{avg("total_fill"):.2%}|')
lines+=['','## Production sold at least once','', '|Scenario|Profession|Produced|First-sale ratio|End product inventory|','|---|---|---:|---:|---:|']
for n,a in groups:
    for prof,name in enumerate(('textile','leather','metal','alchemy')):
        ps=[x['professions'][prof] for x in a]
        lines.append(f'|{n}|{name}|{statistics.mean(p["produced"] for p in ps):,.0f}|{statistics.mean(p["sell_through"] or 0 for p in ps):.2%}|{statistics.mean(x["items"][prof]["inventory"] for x in a):,.0f}|')
lines+=['','## Campaign readiness and investment cash','', '|Scenario|Faction readiness gates met / 6 events per faction|Project capital paid|Unspent refund|','|---|---|---:|---:|']
for n,a in groups:
    if not a[0]['config']['war']:continue
    success=[sum(e['logistics_and_combat_ready'][f] for x in a for e in x['events']) for f in (0,1)]
    lines.append(f'|{n}|{success[0]}/6 ; {success[1]}/6|{statistics.mean(x["investment_paid"] for x in a):,.0f}|{statistics.mean(x["investment_refunded"] for x in a):,.0f}|')
lines+=['','Investment rows model funded procurement and pro-rata unspent refund only. There is no operating revenue/dividend or verified NPC kill model; these are readiness gates, not world victory.','',
'## Interpretation constraints','',
'- Replayed Q30 cash does not consume modeled time or additional battle supplies; all repeat policies remain offline assumptions.',
'- Profession price quotes and raw quotes are fixed candidates. Cash cost basis is actual paid cost; raw executable opportunity profit stays UNKNOWN.',
'- First-sale ratio excludes resales; self-use is not counted as a sale. Inventory is not booked as copper wealth.',
'- Bound system medicine may satisfy personal demand but never project procurement; craft and guarantee contributions remain separate.',
'- Initial merchant cash is included in opening money. Project investments and treasury funding transfer money; procurement authorization mints exactly once.',
'- Finite raw supply is derived from a random actual tower lineup, but tower choice, win probability and four-unit drop are simulation assumptions.',
'- No new-player progression, advanced sealed-item market, dynamic price discovery, investment returns, persistent faction feedback, or actual news-driven participation measured.',
'- Read independent_audit.json for accounting checks; a passing audit is not economic approval.']
(out/'RESULTS.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines[:18]))
