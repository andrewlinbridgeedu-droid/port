"""Validate human device observations and summarize medians; never edit model inputs."""
import argparse
from datetime import date
import json
import math
from pathlib import Path
from statistics import median

ACTIVITIES = {
    'story': '一关主线，含剧情、准备和结算',
    'tower': '一层塔，含进出和结算',
    'bounty': '一个通缉案，调查到领奖',
    'J0': '一单邮务核验，接单到结算',
    'J1': '一单封口巡检，接单到结算',
    'J2': '一单塔内维护，接单到结算；记录层段',
    'craft': '一次制作；记录配方，材料预先持有',
    'sale': '一次卖货；记录物品，商品预先持有',
    'neighbor_deliver': '街坊交货，走近接单到交货；商品预先持有',
    'neighbor_find': '街坊寻物，走近接单到完成',
    'neighbor_message': '街坊传话，走近接单到走到收话人完成',
    'neighbor_pest': '街坊赶塔怪，走近接单到战斗结算',
    'tavern': '一局牌，入局到结算；记录牌种',
    'event_delivery': '一次事件交货，进板到交货；商品预先持有',
    'event_battle': '一场事件战，进板到战斗结算',
    'remnant': '一个残余案，接案、调查、战斗到领奖',
}

def summarize(data):
    errors, summary = [], {}
    if not isinstance(data, dict):
        return ['observations must be an object'], {}
    if type(data.get('schema')) is not int or data['schema'] != 1:
        errors.append('schema must be 1')
    activities = data.get('activities')
    if not isinstance(activities, dict):
        return ['activities must be an object'], {}
    if set(activities) != set(ACTIVITIES):
        errors.append('activity keys must match the template')
    for name in ACTIVITIES:
        samples = activities.get(name, {}).get('samples', []) if isinstance(activities.get(name), dict) else []
        if not isinstance(samples, list) or len(samples) < 3:
            errors.append(f'{name}: at least 3 samples required')
            continue
        values, builds, dates = [], set(), set()
        for i, sample in enumerate(samples):
            label = f'{name}[{i}]'
            if not isinstance(sample, dict):
                errors.append(f'{label}: expected object'); continue
            try:
                seconds = sample['seconds']
                valid = (date.fromisoformat(sample['date']).isoformat() == sample['date']
                         and type(sample['build']) is int and sample['build'] > 0
                         and sample['mode'] == 'human-normal-play'
                         and all(isinstance(sample[k], str) and sample[k].strip() for k in ('device', 'context', 'observer', 'evidence'))
                         and type(seconds) in (int, float) and math.isfinite(seconds) and seconds > 0)
                if not valid:
                    raise ValueError('invalid observation')
            except (KeyError, TypeError, ValueError):
                errors.append(f'{label}: valid date/build/device/context/observer/evidence, human-normal-play and positive seconds required')
                continue
            values.append(seconds); builds.add(sample['build']); dates.add(sample['date'])
        if len(builds) > 1:
            errors.append(f'{name}: do not mix builds in one calibration')
        if len(values) == len(samples):
            summary[name] = {'count': len(values), 'medianSeconds': median(values), 'medianMinutes': median(values)/60,
                             'minSeconds': min(values), 'maxSeconds': max(values), 'builds': sorted(builds), 'dates': sorted(dates)}
    return errors, summary

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path)
    parser.add_argument('--template', action='store_true')
    args = parser.parse_args()
    if args.template:
        data = {'schema': 1, 'status': 'unmeasured', 'activities': {k: {'scope': v, 'samples': []} for k,v in ACTIVITIES.items()}}
        with args.file.open('x') as f: json.dump(data, f, ensure_ascii=False, indent=2); f.write('\n')
        return
    data = json.loads(args.file.read_text())
    errors, summary = summarize(data)
    if errors:
        print(json.dumps({'status': 'incomplete', 'errors': errors}, ensure_ascii=False, indent=2))
        raise SystemExit(1)
    print(json.dumps({'status': 'observations-complete-model-mapping-pending', 'medians': summary}, ensure_ascii=False, indent=2))

if __name__ == '__main__': main()
