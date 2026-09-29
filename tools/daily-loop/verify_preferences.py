"""Compare device Preferences backups without modifying either backup or the device.

Only the explicitly named player's plist may gain --new-key entries. All its old
values must remain equal. Other pre-existing files must stay byte-identical unless
explicitly named as mutable test suites.
New disposable test-suite files are reported separately, never silently ignored.
"""
import argparse
import json
import plistlib
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('before', type=Path)
parser.add_argument('after', type=Path)
parser.add_argument('--player', default='mistport.player-test-01-15.plist')
parser.add_argument('--new-key', action='append', default=[])
parser.add_argument('--mutable-test-suite', action='append', default=[])
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
if args.player in args.mutable_test_suite:
    raise SystemExit('The real player suite cannot be exempted')


def read_files(folder):
    if not folder.is_dir():
        raise SystemExit(f'Missing backup directory: {folder}')
    return {str(p.relative_to(folder)): p.read_bytes() for p in folder.rglob('*') if p.is_file()}


before, after = read_files(args.before), read_files(args.after)
if args.player not in before or args.player not in after:
    raise SystemExit('Player plist missing from one backup')
a, b = plistlib.loads(before[args.player]), plistlib.loads(after[args.player])
added = sorted(b.keys() - a.keys())
changed = sorted(k for k in a if k not in b or a[k] != b[k])
other_changes = sorted(k for k in before if k != args.player and before[k] != after.get(k))
report = {
    'beforeFiles': len(before), 'afterFiles': len(after),
    'playerByteIdentical': before[args.player] == after[args.player],
    'addedPlayerKeys': added, 'changedOrRemovedPlayerKeys': changed,
    'changedOrRemovedOtherFiles': other_changes,
    'allowedTestSuiteChanges': sorted(set(other_changes) & set(args.mutable_test_suite)),
    'newFiles': sorted(after.keys() - before.keys()),
    'passed': set(added) == set(args.new_key) and not changed and not (set(other_changes) - set(args.mutable_test_suite)),
}
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
raise SystemExit(0 if report['passed'] else 1)
