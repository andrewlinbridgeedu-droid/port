"""Shared-only economy check (user 2026-09-30: there is only the shared server).

The 2026-09-30 final check with what tools/progression-sim found keeps chapter one passable
in a shared-only game: main-story first-clear copper moves earlier (`--early-shift` more on Q3
and Q5, the same total taken from Q26-Q30), the recovery line stays at `--recovery`, and the
city-contribution tier content pays copper only after chapter one (+33.6 single-player copper a
day in the errand channel, paid at the same share).

    python3 tools/economy-decisions/shared_only_check.py --out <dir> [--early-shift 100] [--recovery 180] [--share 0.15]
"""
import argparse
import sys
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import final_check as fc  # noqa: E402
import shared_decisions as sd  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--recovery", type=int, default=180)
ap.add_argument("--share", type=float, default=0.15)
ap.add_argument("--tier-post", type=float, default=33.6)
ap.add_argument("--early-shift", type=int, default=100,
                help="copper moved to the Q3 and Q5 first clears, taken evenly from Q26-Q30")
ap.add_argument("--workers", type=int, default=4)
args = ap.parse_args()

_configs = sd.v3.scenario_configs
sd.v3.scenario_configs = lambda: {k: replace(v, recovery_floor_pre_q17=args.recovery) for k, v in _configs().items()}
sd.LOOP["post"]["errands"] += args.tier_post
# Same chapter total, paid earlier: +shift on Q3 and Q5, -2*shift/5 on each of Q26-Q30.
if args.early_shift:
    v3 = sd.v3
    rewards = list(v3.MAINLINE_REWARDS)
    rewards[2] += args.early_shift; rewards[4] += args.early_shift
    for i in range(25, 30):
        rewards[i] -= 2 * args.early_shift // 5
    assert sum(rewards) == sum(v3.MAINLINE_REWARDS) and min(rewards) > 0
    v3.MAINLINE_REWARDS = rewards
    v3.REWARD_QUEUE = v3.build_reward_queue()
fc.SHARE = args.share
sys.argv = ["final_check.py", "--out", args.out, "--workers", str(args.workers)]
fc.main()
