"""Analytic event sizing, not a battle or market simulation. Python stdlib only."""
import json
from pathlib import Path

out=Path(__file__).resolve().parents[2]/'docs/development/economy-agent-sim-20260926/event-preparation'
out.mkdir(exist_ok=True)
rows=[]
for participants in (200,400,600):
    for win_probability in (.25,.45,.65):
        attempts=participants*3
        expected_wins=attempts*win_probability
        rows.append(dict(participants=participants,attempts_per_person=3,
            win_probability=win_probability,expected_wins=expected_wins,
            old_fog_gate=480,mean_reaches_old_gate=expected_wins>=480,
            expected_wear_per_equipped_copy=3*(2*win_probability+5*(1-win_probability))))
capacity=[]
for baseline in (117.45,160,200):
    for delivery_cycles in (3,10):
        capacity.append(dict(baseline_doses_per_cycle=baseline,cycles=delivery_cycles,
            capacity_per_cycle=160,event_extra_doses=300,
            net_surplus=(160-baseline)*delivery_cycles-300))
result=dict(status='analytic_assumptions_only',combat=rows,supply=capacity,
    caveats=['3 attempts is an assumed time budget, not a new live participation limit.',
        'Expected wins do not certify event success probability; no correlated failures modeled.',
        '160 doses is a perfect-chain upper bound, not measured production.',
        '300 event doses is a sizing probe, not approved demand; excludes extra battle medicine.',
        'No guarantee-source doses may satisfy tradable event delivery.'])
(out/'calculation.json').write_text(json.dumps(result,indent=2)+'\n')
lines=['# Event preparation arithmetic','', 'Analytic sensitivity only. No game changes, no new 2000-agent runs.','',
'|Participants|Win chance assumption|Expected wins from 3 attempts each|Old fog gate|Wear per equipped copy|',
'|---:|---:|---:|---:|---:|']
for r in rows:lines.append(f'|{r["participants"]}|{r["win_probability"]:.0%}|{r["expected_wins"]:.0f}|480|{r["expected_wear_per_equipped_copy"]:.1f}|')
lines+=['','|Baseline demand/cycle|Preparation + delivery cycles|Capacity minus baseline minus extra 300|','|---:|---:|---:|']
for r in capacity:lines.append(f'|{r["baseline_doses_per_cycle"]}|{r["cycles"]}|{r["net_surplus"]:.2f}|')
lines+=['']+result['caveats']
(out/'RESULTS.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
