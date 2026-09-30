"""Final check of the delegated shared-server package (2026-09-30).

The user delegated the open choices. Chosen package: keep the 24/12 NPC scale; the shared
server pays the new daily systems 15% of single-player copper from the city budget (levy cap
20% of NPC basket and open-service sales); players buy one protected basket per active day
(D3); local copper enters at the same 15% rate, counting at most 12,000 local copper.
Rule fixed before running: the package is kept only if every normal year, the repaired supply
shock, dormant return, investment heat, local import and underground runs pass L1, L2_strict
and L3 with at least 95% of the daily-loop copper paid; the unbacked-mint controls must still
fail L2_strict.

    python3 tools/economy-decisions/final_check.py --out <dir> [--workers 4]
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shared_decisions as sd  # noqa: E402

SHARE, TAX, NEED, RATE = 0.15, 0.20, 1.0, 0.15


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--out", required=True); ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    base = sd.Ext("final", "final", "launch_base", loop="funded", share=SHARE, tax=TAX, need_increment=NEED)
    normal = [replace(base, name=f"{b}·定案", base=b) for b in ("launch_base", "steady_fresh20", "dormant_return_200", "investment_heat", "supply_half_90_repair")]
    normal += [replace(base, name="launch_base·定案·带入12000按15%", import_cap=sd.LOCAL_BALANCE_CAP, import_rate=RATE),
               replace(base, name="launch_base·定案·带入12000不折算", import_cap=sd.LOCAL_BALANCE_CAP),
               replace(base, name="launch_base·定案·地下委托", underground=True),
               replace(base, name="steady_fresh20·定案·地下委托", base="steady_fresh20", underground=True)]
    controls = [replace(base, name="反例·照单机发币", loop="mint", share=1.0, control=True),
                replace(base, name="反例·每活跃玩家每天无源+30", loop="none", unbacked_per_active=30, control=True)]
    results = sd.run_family(normal + controls, args.workers)
    g = sd.group(results)
    ok_normal = {n: all(r["L1"] and r["L2_strict"] and r["L3"] for r in runs) and statistics.mean(r["loop_paid_share"] or 0 for r in runs) >= 0.95
                 for n, runs in g.items() if not runs[0]["ext"]["control"]}
    caught = {n: all(not r["L2_strict"] for r in runs) for n, runs in g.items() if runs[0]["ext"]["control"]}
    kept = all(v for k, v in ok_normal.items() if "不折算" not in k) and all(caught.values())
    decision = (f"**定案复核**：{'通过' if kept else '未通过'}。正常与冲击情景：{json.dumps(ok_normal, ensure_ascii=False)}；"
                f"反例被严格线挡住：{json.dumps(caught, ensure_ascii=False)}。（“不折算”一行只作对照，不计入判定。）")
    report = ["# 共享服定案复核（2026-09-30）", "", __doc__.strip().split("\n\n")[1], "", "5 个种子 × 365 天，Pro V3 模型＋钩子，是设计模型。", ""] + sd.table(results) + ["", decision, ""]
    (out / "report.md").write_text("\n".join(report) + "\n")
    (out / "decision.json").write_text(json.dumps({"kept": kept, "normal": ok_normal, "controls": caught}, ensure_ascii=False, indent=1))
    print("\n".join(report))


if __name__ == "__main__":
    main()
