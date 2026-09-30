"""Sensitivity: the 2026-09-30 final check with extra daily-loop copper added to errands.

    python3 tools/economy-decisions/final_check_tiers.py <chapter extra/day> <post extra/day> <out dir>

Run from the repo root. City contribution tier content (2026-09-30): 20.4 and 33.6.
"""
import sys, runpy
from pathlib import Path
sys.path.insert(0, str(Path("tools/economy-decisions").resolve()))
import shared_decisions as sd
before = {k: dict(v) if isinstance(v, dict) else v for k, v in sd.LOOP.items()}
sd.LOOP["chapter"]["errands"] += float(sys.argv[1])
sd.LOOP["post"]["errands"] += float(sys.argv[2])
print("LOOP before", before["chapter"], before["post"])
print("LOOP after ", sd.LOOP["chapter"], sd.LOOP["post"])
sys.argv = ["final_check.py", "--out", sys.argv[3], "--workers", "4"]
runpy.run_path("tools/economy-decisions/final_check.py", run_name="__main__")
