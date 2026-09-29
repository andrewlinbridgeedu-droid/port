"""Verify recipe material coverage against actual opening-floor species source."""
import json,re
from pathlib import Path
from check_catalog import enumerate_recipe
root=Path(__file__).resolve().parents[2]
source=(root/'mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift').read_text()
short={'shieldJaw':['shell_chip','sinew_cord'],'saltSac':['saline_powder','resilient_membrane'],'backSac':['resilient_membrane','restorative_gel'],'scissor':['shell_chip','sinew_cord'],'crown':['mist_fiber','veil_filament'],'boneclaw':['sinew_cord','copper_scale'],'copperback':['shell_chip','copper_scale'],'crimsonBrute':['shell_chip','sinew_cord'],'veilOracle':['mist_fiber','veil_filament'],'goldenThroat':['resilient_membrane','restorative_gel','saline_powder'],'moonfang':['saline_powder','mist_fiber']}
catalog=json.loads(Path(__file__).with_name('catalog.json').read_text())
available=set();report={}
for line in source.splitlines():
    m=re.search(r'Floor\(number: (\d+),',line)
    if not m:continue
    floor=int(m[1]);species=re.findall(r'small\(\.(\w+)',line)
    if 'jaw(' in line:species.append('shieldJaw')
    if 'sac(' in line:species.append('saltSac')
    for sp in species:available.update('craft_'+x for x in short[sp])
    for recipe in catalog['recipes']:
        solutions=[s for s in enumerate_recipe(catalog,recipe) if all(o is None or o['id'] in available for o in s['materials'])]
        if len(solutions)>=2 and recipe['id'] not in report:
            report[recipe['id']]={'firstFloorWithTwoMaterialSolutions':floor,'solutions':len(solutions)}
assert len(report)==len(catalog['recipes']),set(r['id'] for r in catalog['recipes'])-set(report)
print(json.dumps({'scope':'material pool accessibility only; not drop guarantee, battle difficulty or recipe unlock','recipes':report},ensure_ascii=False,indent=2))
