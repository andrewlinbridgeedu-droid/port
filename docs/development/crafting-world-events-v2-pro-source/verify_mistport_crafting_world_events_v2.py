#!/usr/bin/env python3
"""Independent verifier for Mistport crafting/world-event v2 CSV outputs."""
from __future__ import annotations
import csv, importlib.util, math, sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv)>1 else '/mnt/data/mistport_crafting_world_events_v2_results')
MODEL = Path(sys.argv[2] if len(sys.argv)>2 else '/mnt/data/mistport_crafting_world_events_v2.py')

def load(name):
    with (ROOT/name).open(encoding='utf-8') as f: return list(csv.DictReader(f))

def fail(msg): raise AssertionError(msg)

# Import model constants without running main.
spec=importlib.util.spec_from_file_location('mistv2',MODEL); mod=importlib.util.module_from_spec(spec); sys.modules['mistv2']=mod; spec.loader.exec_module(mod)
assert mod.ONE_TIME_TOTAL==5220
assert len(mod.PRODUCT['tea']['variants'])>=2 and 'mist_fiber' in mod.PRODUCT['tea']['variants'][1]
assert mod.BASIC_ALLOWANCE==28 and mod.PASS_EXTRA==28

rows=load('daily_results.csv')
assert rows, 'daily_results empty'
for r in rows:
    if int(float(r['money_error']))!=0: fail(('money error',r['scenario'],r['seed'],r['day']))
    for k,v in r.items():
        if k.startswith(('base_','matstock_','inventory_')) and float(v)<0:
            fail(('negative stock',k,r['scenario'],r['day'],v))
    if float(r['player_cash'])<0 or float(r['event_escrow_total'])<0: fail('negative cash')
    if int(r['repair_gross_today']) != int(r['repair_savings_today']) + int(r['repair_sink_today']): fail(('repair accounting',r['scenario'],r['day']))

events=load('event_outcomes.csv')
defs={r['event_id']:r for r in load('event_definitions.csv')}
for r in events:
    d=defs[r['event_id']]
    budget=float(d['budget_normal'])*float(r['scale'])
    if float(r['spent']) > budget + 2: fail(('event overspent',r,budget))
    success=(r['success']=='True')
    rule=float(r['goods_min_fill'])>=.70 and float(r['combat_fill'])>=.80
    if success!=rule: fail(('event success predicate mismatch',r))

prof=load('proficiency_farming.csv')
assert {r['profession'] for r in prof}==set(mod.PROFS)
for r in prof:
    assert int(r['median_tower_wins'])>0 and int(r['p90_tower_wins'])>=int(r['median_tower_wins'])

checks=load('invariant_checks.csv')
if not all(r['passed']=='True' for r in checks): fail(('embedded check failed',checks))
print('PASS')
print('daily_rows',len(rows))
print('event_outcomes',len(events))
print('scenarios',len({r['scenario'] for r in rows}))
print('seeds',sorted({r['seed'] for r in rows}))
