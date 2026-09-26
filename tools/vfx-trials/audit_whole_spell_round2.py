#!/usr/bin/env python3
"""Audit delivered recordings against fresh completed-row receipts and decoded frames.

This verifies evidence integrity, not visual approval or native/phone gameplay.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/whole-spell-round2-20260922"


def main():
    plan = json.loads((OUT / "capture-plan.json").read_text())
    decoded = {c["clip"]: c for c in json.loads((OUT / "after-index.json").read_text())["clips"]}
    ledgers = [(p, set(p.read_text().splitlines())) for p in OUT.glob("record-*-recorded.txt")]
    results, failures = [], []
    for row in plan["rows"]:
        key = row["key"]
        paths = [OUT / "after" / (key + suffix + ".mp4") for suffix in ("", "-close")]
        issues = []
        if not all(p.is_file() for p in paths):
            failures.append(key + ": missing full or close recording")
            continue
        latest_video = max(p.stat().st_mtime for p in paths)
        eligible = [p for p, keys in ledgers if key in keys and p.stat().st_mtime >= latest_video - .1]
        if not eligible:
            issues.append("no completed-row receipt newer than the actual video files")
        clips = []
        for path in paths:
            rel = str(path.relative_to(ROOT))
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            evidence = decoded.get(rel)
            if not evidence or evidence["sha256"] != digest:
                issues.append(path.name + ": chronological review sheet is missing or stale")
            elif evidence["sampled_frames"] != 48 or abs(evidence["duration"] - row["frames"] / 30) > .04:
                issues.append(path.name + ": duration or full-timeline sample count mismatch")
            clips.append(dict(path=rel, sha256=digest, duration=evidence["duration"] if evidence else None))
        results.append(dict(key=key, id=row["id"], expected_contacts=row["expected"],
                            receipt=max(eligible, key=lambda p: p.stat().st_mtime).name if eligible else None,
                            clips=clips, issues=issues))
        failures.extend(key + ": " + issue for issue in issues)
    summary = dict(kind="recording integrity only; not visual approval or phone acceptance",
                   rows=len({r["id"] for r in plan["rows"]}), pairs=len(plan["rows"]),
                   clips=sum(len(r["clips"]) for r in results), failures=failures, results=results)
    (OUT / "delivery-validation.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: summary[k] for k in ("rows", "pairs", "clips", "failures")}, ensure_ascii=False))
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
