"""S2: the shared-server economy with NPC prices and money scaled by 16 (2026-09-30).

The user delegated the choice between paying the shared-server daily loop a small share
of single-player copper, scaling NPC prices, or lowering single-player copper. D4 showed
that at 16x NPC scale the full single-player daily loop can be paid from the city budget,
but only at V3's default player basket need (0.25 a day), not at D3's one basket per active
day. This checks that combination before deciding. Rule fixed before running (RULE below).

    python3 tools/economy-decisions/scale_check.py --out <dir> [--workers 4]
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from dataclasses import asdict, replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shared_decisions as sd  # noqa: E402

SCALE = 16.0
NEEDS = (0.25, 0.5, 1.0)
TAXES = (0.02, 0.05, 0.1, 0.2)
BASES = ("launch_base", "steady_fresh20", "supply_half_90_repair")

RULE = ("S2（×16 标尺）：NPC 价格与资金乘 16，每日玩法按单机全额由城市预算付。取两个正常年份与“修复的供给减半”"
        "在玩家篮子覆盖 1.0（D3）时都过 L1、L2_strict、L3 且平均实付 ≥95% 的最低税率；若覆盖 1.0 没有税率能过，"
        "改报能过的最大覆盖与最低税率。另报同一方案下带入 12,000、地下委托、另两个正常情景和照单机发币对照。")


def grid():
    return [sd.Ext(f"{b}·×16·篮子{n:g}·税{int(t * 100)}%", "scale16", b, loop="funded", share=1.0, tax=t, need_increment=n, scale=SCALE)
            for b in BASES for n in NEEDS for t in TAXES]


def passes(runs):
    return all(r["L1"] and r["L2_strict"] and r["L3"] for r in runs) and statistics.mean(r["loop_paid_share"] or 0 for r in runs) >= 0.95


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--out", required=True); ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    results = sd.run_family(grid(), args.workers)
    g = sd.group(results)
    chosen = None
    for need in sorted(NEEDS, reverse=True):
        for tax in TAXES:
            if all(passes(g[f"{b}·×16·篮子{need:g}·税{int(tax * 100)}%"]) for b in BASES):
                chosen = (need, tax); break
        if chosen: break
    report = ["# S2：×16 标尺复核", "", "模型同 `shared_decisions.py`（Pro V3 整服模型＋钩子），5 个种子 × 365 天。是设计模型，不是游戏实装。", "",
              f"- **规则**：{RULE}", "", "## 网格", ""] + sd.table(results) + [""]
    if chosen:
        need, tax = chosen
        base = sd.Ext("S2", "s2", "launch_base", loop="funded", share=1.0, tax=tax, need_increment=need, scale=SCALE)
        extras = [
            replace(base, name="launch_base·×16·带入≤12000", import_cap=sd.LOCAL_BALANCE_CAP),
            replace(base, name="launch_base·×16·地下委托", underground=True),
            replace(base, name="steady_fresh20·×16·地下委托", base="steady_fresh20", underground=True),
            replace(base, name="dormant_return_200·×16", base="dormant_return_200"),
            replace(base, name="investment_heat·×16", base="investment_heat"),
            replace(base, name="反例·×16·照单机发币", loop="mint", control=True),
            replace(base, name="反例·×16·每活跃玩家每天无源+480", loop="none", unbacked_per_active=480, control=True),
        ]
        more = sd.run_family(extras, args.workers)
        results += more
        normal_ok = all(r["L1"] and r["L2_strict"] and r["L3"] for r in more if not r["ext"]["control"])
        below = statistics.mean(r["below_floor_share"] for r in more if not r["ext"]["control"])
        controls = {n: all(not r["L2_strict"] for r in runs) for n, runs in sd.group([r for r in more if r["ext"]["control"]]).items()}
        decision = (f"**S2 判定**：×16 标尺下每日玩法可按单机全额付，玩家篮子覆盖 {need:g}，城市预算税率上限 {tax:.0%}。"
                    f"加上带入 12,000、地下委托与另两个正常情景{'仍全部' if normal_ok else '未全部'}过 L1/L2 严格/L3，平均 {below:.1%} 的活跃玩家低于恢复线；"
                    f"反例是否被严格线挡住：{json.dumps(controls, ensure_ascii=False)}。")
        report += ["## 选定方案下的其他情景", ""] + sd.table(more) + ["", decision, ""]
    else:
        decision = "**S2 判定**：×16 标尺下没有覆盖和税率组合能在三个情景都过线，不能按单机全额付。"
        report += [decision, ""]
    (out / "report.md").write_text("\n".join(report) + "\n")
    (out / "decision.json").write_text(json.dumps({"chosen": chosen, "text": decision}, ensure_ascii=False, indent=1))
    (out / "results.json").write_text(json.dumps([{"name": r["ext"]["name"], "seed": r["seed"], **{k: r[k] for k in (
        "peak_index", "max_30d_change", "annual_change", "fill_min", "loop_paid_share", "player_cash_median", "below_floor_share",
        "recovery_fund_min", "L1", "L2_primary", "L2_strict", "L3")}} for r in results], ensure_ascii=False, indent=1))
    print("\n".join(report))


if __name__ == "__main__":
    main()
