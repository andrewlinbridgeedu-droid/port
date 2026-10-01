#!/usr/bin/env python3
"""Read-only, bytewise device backup comparison for the isolated tempo review.

Never restore a backup. Real player/audit files have no exemptions. The sole
standard preference allowance is the newly introduced presentation-speed key;
every older key must keep its original value.
"""
import argparse
import hashlib
import json
import plistlib
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("before", type=Path)
parser.add_argument("after", type=Path)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--allow-review", action="store_true")
args = parser.parse_args()

def files(folder):
    if not folder.is_dir():
        raise SystemExit("Missing Preferences backup")
    return {str(p.relative_to(folder)): p.read_bytes() for p in folder.rglob("*") if p.is_file()}

before, after = files(args.before), files(args.after)
real = ["mistport.player-test-01-15.plist", "mistport.player-test-01-15.audit.plist"]
standard = "com.yourcompany.mistport.plist"
review = "mistport.combat-tempo-review.20261001.plist"
speed_key = "mistport.combat.presentation-speed.v1"
unexpected, allowed, checked = [], [], []
for name in sorted(before):
    identical = before[name] == after.get(name)
    checked.append({"file": name, "byteIdentical": identical,
                    "beforeSHA256": hashlib.sha256(before[name]).hexdigest(),
                    "afterSHA256": hashlib.sha256(after[name]).hexdigest() if name in after else None})
    if identical:
        continue
    permitted = args.allow_review and name == review and name in after
    if args.allow_review and name == standard and name in after:
        old, new = plistlib.loads(before[name]), plistlib.loads(after[name])
        # This allowance cannot hide changes to any pre-existing setting.
        permitted = speed_key not in old and set(new) - set(old) == {speed_key}
        permitted = permitted and all(k in new and new[k] == v for k, v in old.items())
        permitted = permitted and new.get(speed_key) in [1, 2]
    (allowed if permitted else unexpected).append(name)
new_files = sorted(after.keys() - before.keys())
for name in new_files:
    if not (args.allow_review and name == review):
        unexpected.append(name)
real_identical = all(name in before and name in after and before[name] == after[name] for name in real)
report = {"beforeFiles": len(before), "afterFiles": len(after), "realPlayerAndAuditByteIdentical": real_identical,
          "allowedChangedFiles": allowed, "newFiles": new_files, "unexpectedChangedOrNewFiles": unexpected,
          "files": checked, "passed": real_identical and not unexpected,
          "restoredAnything": False, "realPlayerExempted": False}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({k: v for k, v in report.items() if k != "files"}, ensure_ascii=False, indent=2))
raise SystemExit(0 if report["passed"] else 1)
