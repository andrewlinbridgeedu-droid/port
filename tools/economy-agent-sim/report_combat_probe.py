"""Read actual Swift runtime probe output; no synthetic combat outcomes."""
import hashlib,json,statistics
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=root/'docs/development/world-campaign-prototype-20260927'
log=out/'prototype-tests.log'
rows=[json.loads(line.split('CAMPAIGN_PROBE ',1)[1]) for line in log.read_text().splitlines() if line.startswith('CAMPAIGN_PROBE ')]
assert len(rows)==288,len(rows)
keys=[(r['encounter'],r['gear_floor'],r['passive'],r['carried_medicine'],r['active_medal'],r['seed']) for r in rows]
assert len(set(keys))==288
assert all(r['outcome'] in ('victory','defeat','inProgress') and 0<=r['medicine_used']<=r['carried_medicine'] for r in rows)
(out/'combat-probe.json').write_text(json.dumps(rows,indent=2)+'\n')
lines=['# Existing-combat preparation probe','',
'288 deterministic runtime trials: 3 encounters × 2 earned equipment sets × 4 passive relic choices × 2 medicine inventories × 2 active-medal choices × 3 timing seeds.',
'No new NPC content, human playtest, or probabilistic real-player win-rate claim. Existing B03/B06/F90 are isolated mechanical fixtures.',
'Four Q30 skills/talents. Active life medal and passive relic choice vary. Gear is earned through tower floor 30 or 100. Timing jitter ±0.25s; automatic medicine below half normal max HP. Timeout 360s.',
'No forced damage in these runs. Settlement unit tests use forced victory fixtures separately and are excluded.',
'', '|Encounter|Earned gear through floor|Passive|Carried medicine|Active medal|Wins / 3|Timeouts|Mean winning seconds|Mean consumed doses|Mean ordinary repair copper|',
'|---|---:|---|---:|---|---:|---:|---:|---:|---:|']
for encounter,gear,passive,carried,medal in sorted(set(k[:5] for k in keys)):
    a=[r for r in rows if (r['encounter'],r['gear_floor'],r['passive'],r['carried_medicine'],r['active_medal'])==(encounter,gear,passive,carried,medal)]
    wins=[r for r in a if r['outcome']=='victory']
    elapsed=f'{statistics.mean(r["seconds"] for r in wins):.2f}' if wins else 'NA'
    lines.append(f'|{encounter}|{gear}|{passive}|{carried}|{medal}|{len(wins)}|{sum(r["outcome"]=="inProgress" for r in a)}|{elapsed}|{statistics.mean(r["medicine_used"] for r in a):.2f}|{statistics.mean(r["repair_copper"] for r in a):.2f}|')
lines+=['','Repair uses the existing owned-relic ledger on a pristine ordinary item after each trial. Full repair after each battle includes rounding and is not an optimized multi-battle maintenance policy. Special medal is outside ordinary wear.',
'Medicine stock is an isolated fixture; no player wallet is charged. Multiply actual doses by candidate craft price 16 or existing system price 30 only for sensitivity, not guaranteed market cost.',
'No target copper sink, price elasticity, real player decision, relic purchase demand or campaign success rate can be inferred from these trials alone.']
(out/'COMBAT_RESULTS.md').write_text('\n'.join(lines)+'\n')
files=['mistport-ios/MistportCombatCore/Sources/MistportCombatCore/WorldCampaignPrototype.swift',
'mistport-ios/MistportCombatCore/Tests/MistportCombatCoreTests/WorldCampaignPrototypeTests.swift',
'mistport-ios/MistportCombatCore/Tests/MistportCombatCoreTests/CampaignCombatProbeTests.swift',
'mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift',
'mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchOwnedRelicLedger.swift',
'mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchGear.swift',
'mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift',
'mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift']
(out/'source-hashes.json').write_text(json.dumps({p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in files},indent=2)+'\n')
print(json.dumps({'runs':len(rows),'wins':sum(r['outcome']=='victory' for r in rows),'timeouts':sum(r['outcome']=='inProgress' for r in rows)},indent=2))
