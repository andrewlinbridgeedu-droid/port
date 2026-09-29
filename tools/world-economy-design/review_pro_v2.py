#!/usr/bin/env python3
"""Reproduce the preserved Pro model without changing its economic logic.

Standard library only. Outputs live in a temporary directory; the compact audit
is written next to this script. This verifies accounting/reproduction, not balance.
"""
import csv
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/development/crafting-world-events-v2-pro-source'
MODEL = SOURCE / 'mistport_crafting_world_events_v2.py'
ORIGINAL = SOURCE / 'mistport_crafting_world_events_v2_final_results'


def read(path):
    with path.open(encoding='utf-8', newline='') as f:
        return list(csv.DictReader(f))


def main():
    with tempfile.TemporaryDirectory(prefix='mistport-v2-review-') as work:
        work = Path(work)
        output = work / 'results'
        local = work / 'model_local.py'
        old = "OUT = Path('/mnt/data/mistport_crafting_world_events_v2_results')"
        source = MODEL.read_text()
        assert source.count(old) == 1
        local.write_text(source.replace(old, f'OUT = Path({str(output)!r})'))
        subprocess.run([sys.executable, str(local)], check=True)
        verified = subprocess.run([sys.executable, str(SOURCE / 'verify_mistport_crafting_world_events_v2.py'), str(output), str(local)], check=True, capture_output=True, text=True)
        comparison = {}
        differences = []
        for path in sorted(output.glob('*.csv')):
            original = ORIGINAL / path.name
            comparison[path.name] = path.read_bytes() == original.read_bytes()
            a, b = read(original), read(path)
            assert len(a) == len(b), path.name
            for i, (left, right) in enumerate(zip(a, b), 2):
                assert left.keys() == right.keys(), path.name
                for key in left:
                    if left[key] == right[key]:
                        continue
                    try:
                        if Decimal(left[key]) == Decimal(right[key]):
                            continue
                    except InvalidOperation:
                        pass
                    differences.append({'file': path.name, 'csv_line': i, 'column': key, 'source': left[key], 'rerun': right[key]})
        # Independently add nine published opening balances, then recompute
        # the money identity; do not trust the model's money_error column.
        opening = sum([200000, 100000, 30000, 60000, 120000, 60000, 60000, 80000, 50000])
        daily = read(output / 'daily_results.csv')
        for row in daily:
            n = lambda k: int(row[k])
            assert n('money_total') == opening + n('issuance_cum') - n('sink_cum') - n('external_outflow_cum')
            assert n('issuance_cum') == sum(n(k) for k in ('issue_allowance_cum', 'issue_pass_cum', 'issue_existing_cum', 'issue_repeat_cum'))
        # These are published model inputs/results, not a runtime account audit.
        report = {
            'source_sha256': hashlib.sha256(MODEL.read_bytes()).hexdigest(),
            'economic_logic_modified': False,
            'only_patch': 'OUT path redirected into temporary directory',
            'supplied_verifier': verified.stdout.strip(),
            'daily_rows_independently_reconciled': len(daily),
            'opening_model_money': opening,
            'byte_equal': comparison,
            'semantic_differences': differences,
            'not_regenerated': sorted(p.name for p in ORIGINAL.glob('*.csv') if not (output / p.name).exists()),
            'limits': ['Aggregate player wallet cannot prove individual affordability.', 'Prices are simulated quotes, not observed CPI.', 'Turnover is incorrectly repriced after sales in preserved model.', 'No live database, concurrency, or player-save verification.'],
        }
        target = Path(__file__).with_name('pro-v2-review.json')
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(target)
        print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
