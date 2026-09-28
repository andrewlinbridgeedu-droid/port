"""Audit the pasted Pro reply against existing results; never invent battle runs.

Uses stdlib only. Writes a paired evidence report and a candidate 72-run plan.
The plan is not an executed encounter or a real-player win-rate estimate.
"""
import hashlib
import itertools
import json
import math
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/development/world-campaign-prototype-20260927"
OUT = EVIDENCE / "pro-final-review"


def wilson(wins, n, z=1.959963984540054):
    assert 0 <= wins <= n and n > 0
    p = wins / n
    center = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return [max(0, center - half), min(1, center + half)]


def money_until_success(p, attempt_cost, attempt_seconds, success_reward=0):
    # IID retries, no skill learning, no deadline, same strategy every attempt.
    # Includes failed attempts; this is not a live-market willingness to pay.
    assert 0 < p <= 1 and attempt_cost >= 0 and attempt_seconds > 0
    return {
        "expected_attempts": 1 / p,
        "expected_cost": attempt_cost / p,
        "expected_seconds": attempt_seconds / p,
        "net_reward": success_reward - attempt_cost / p,
    }


def audit():
    rows = json.loads((EVIDENCE / "combat-probe.json").read_text())
    key = lambda r: (r["encounter"], r["gear_floor"], r["passive"], r["active_medal"], r["seed"])
    without = {key(r): r for r in rows if r["carried_medicine"] == 0}
    with_med = {key(r): r for r in rows if r["carried_medicine"] == 3}
    assert len(rows) == 288 and len(without) == len(with_med) == 144
    assert without.keys() == with_med.keys()
    pairs = []
    for k in sorted(without):
        a, b = without[k], with_med[k]
        pairs.append({
            "encounter": k[0], "gear_floor": k[1], "passive": k[2],
            "active_medal": k[3], "seed": k[4],
            "without": a, "with": b,
            "seconds_saved": a["seconds"] - b["seconds"],
            "extra_remaining_hp": b["hp"] - a["hp"],
        })
    summary = []
    for encounter in sorted({r["encounter"] for r in rows}):
        p = [r for r in pairs if r["encounter"] == encounter]
        summary.append({
            "encounter": encounter, "pairs": len(p),
            "wins_without": sum(r["without"]["outcome"] == "victory" for r in p),
            "wins_with": sum(r["with"]["outcome"] == "victory" for r in p),
            "same_duration": sum(r["seconds_saved"] == 0 for r in p),
            "mean_seconds_without": statistics.mean(r["without"]["seconds"] for r in p),
            "doses": sum(r["with"]["medicine_used"] for r in p),
            "mean_extra_hp": statistics.mean(r["extra_remaining_hp"] for r in p),
        })
    confidence = [{"n": n, "wins": n // 2, "wilson95": wilson(n // 2, n)} for n in [2, 10, 20, 100, 200]]
    # IID illustration; shared human errors and attendance can invalidate independence.
    campaign_success = [
        {"individual_p": p, "independent_challenges": n,
         "at_least_one_kill": 1 - (1 - p) ** n,
         "both_npcs_dead_if_symmetric": (1 - (1 - p) ** n) ** 2}
        for p, n in itertools.product([.35, .50, .65], [1, 3, 10, 30])
    ]
    # Illustrative arithmetic only, not fitted to the existing all-win evidence.
    # Preparation costs 3 extra copper per attempt, improving p .45 -> .65.
    bare = money_until_success(.45, 4, 90)
    prepared = money_until_success(.65, 7, 80)
    retry_example = {
        "status": "illustrative_assumptions_not_game_evidence",
        "bare": bare, "prepared": prepared,
        "cash_saving_per_success": bare["expected_cost"] - prepared["expected_cost"],
        "seconds_saved_per_success": bare["expected_seconds"] - prepared["expected_seconds"],
        "max_extra_attempt_cost_for_cash_parity": 4 * (.65 / .45 - 1),
    }
    # Pre-register one tactical ordinary item per encounter. No post-hoc winner picking.
    relics = {"campaign_core_guard_v1": "relic_salt_sealed_breathing_bag",
              "campaign_core_relay_v1": "relic_return_gift_clasp"}
    plan = []
    for boss, gear, operator, supply, seed in itertools.product(
        relics, [30, 100], ["clean", "human_mid_assumed", "human_stress_assumed"],
        ["none", "salve3", "salve3_ordinary"], [101, 211]
    ):
        plan.append({
            "run_id": f"{boss}-g{gear}-{operator}-{supply}-s{seed}",
            "encounter": boss, "gear_floor": gear, "operator": operator,
            "medicine": 0 if supply == "none" else 3,
            "ordinary_relic": relics[boss] if supply == "salve3_ordinary" else None,
            "active_medal": False, "seed": seed,
            "error_tape_key": f"{operator}:{seed}",
            "status": "planned_not_executed",
        })
    assert len(plan) == len({r["run_id"] for r in plan}) == 72
    receipt = {
        "evidence": "existing_combat_pairs_not_new_core_battles",
        "summary": summary, "pairs": pairs, "sample_size_examples": confidence,
        "retry_example": retry_example, "campaign_probability_examples": campaign_success,
        "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [EVIDENCE / "combat-probe.json", OUT / "PRO_REPLY.txt", Path(__file__)]},
    }
    (OUT / "audit.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    (OUT / "core-probe-plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n")
    lines = ["# Pro 核心战建议：本地复核", "",
        "输入：用户粘贴的 Pro 回复与已有 288 次程序策略战斗结果。没有新增真人试验或核心战实录。",
        "", "## 144 对同配置用药对照", "",
        "逐对固定遭遇、装备、普通封印物、主动勋章与 seed，仅改变携药数量。",
        "", "|遭遇|配对数|无药/有药获胜|相同时长的配对|有药组总用量|平均增加剩余 HP|",
        "|---|---:|---:|---:|---:|---:|"]
    for s in summary:
        lines.append(f'|{s["encounter"]}|{s["pairs"]}|{s["wins_without"]}/{s["wins_with"]}|{s["same_duration"]}|{s["doses"]}|{s["mean_extra_hp"]:.2f}|')
    lines += ["", "144 对胜负和时长均相同，有药组共消耗 98 份药；其中 71 对剩余 HP 更高。",
        "可确认当前策略没有测出药带来的胜率/时长提升，但它确实改变了部分剩余生命。不能把全部用药称为无效，也不能由较高剩余 HP 推出真人愿付价。",
        "Pro 的 32.32 秒、66.57/80.28 秒未注明配置，本报告采用全部匹配数据，不将零散均值作为整批结论。",
        "", "## 72 次矩阵能证明什么", "",
        "2 遭遇 × 2 装备 × 3 操作模型 × 3 携物 × 2 seed = 72；每个完整配置只有 2 次。",
        "因此胜率只能取 0%、50%、100%，不能用来验收 35%–55% 或 55%–75%。",
        "下表仅说明独立伯努利样本的 Wilson 95% 区间宽度；机器人 seed 不是独立真人样本。", "",
        "|每配置尝试 n|成功次数|95% 区间|", "|---:|---:|---:|"]
    for c in confidence:
        lines.append(f'|{c["n"]}|{c["wins"]}|{100*c["wilson95"][0]:.1f}%–{100*c["wilson95"][1]:.1f}%|')
    lines += ["", "100–200 次真人尝试如果分散在 36 个条件且来自重复玩家，仍不足以冻结每个条件的胜率。先用于发现操作错误和机制问题；后续按玩家聚类、首尝/复尝分开估计，报告区间而不是只报比例。",
        "", "## 个人难度不等于全服战役难度", "",
        "假设挑战独立、各方有相同数量票据且都尝试；一次合法击杀即使目标死亡。下表是算式敏感性，不是真人行为预测。",
        "", "|单次成功率|每方挑战数|至少一次击杀|对称两方均击杀概率|", "|---:|---:|---:|---:|"]
    for c in campaign_success:
        lines.append(f'|{100*c["individual_p"]:.0f}%|{c["independent_challenges"]}|{100*c["at_least_one_kill"]:.2f}%|{100*c["both_npcs_dead_if_symmetric"]:.2f}%|')
    lines += ["", "实际票据签发、暴露时间、宽限、参战率与玩家错误相关性会改变结果。不能因为双方人数多就不断抬高单人难度或售卖稀有门票；先定义世界胜负目标，再独立验证参与可及性与死亡规则。",
        "", "## 现金、胜率与时间分账", "",
        "Pro 的单次期望差公式只适用于相同尝试口径；物品自身成本必须单列，避免在药费、维护和重试费里重复扣除。重复直至成功时，若每次独立且固定成功率 p、无截止、单次平均成本 c/时长 t：期望现金成本 c/p，期望时间 t/p。",
        "候选算例：无准备 p=45%、每次4铜/90秒；有准备 p=65%、每次7铜/80秒。",
        f'有准备每次成功预期多花 {-retry_example["cash_saving_per_success"]:.2f} 铜，同时节省 {retry_example["seconds_saved_per_success"]:.2f} 秒。提高胜率不能自动等同赚钱。',
        f'此例使现金成本持平的额外耗材价仅为 {retry_example["max_extra_attempt_cost_for_cash_parity"]:.2f} 铜/次；这不是实际物品定价。',
        "世界战役有窗口、有限票据、玩家学习及败方退出，必须用带截止的尝试记录估计；不能直接套无限重试公式。剧情、荣誉、经营资格和节省时间均不自动折铜。",
        "", "## 产物与复现", "",
        "`audit.json` 保留每对输入和差值、算例及来源散列。`core-probe-plan.json` 是 72 项待执行计划，全部明确标为 planned_not_executed。",
        "执行：`PYTHONDONTWRITEBYTECODE=1 python3 tools/economy-agent-sim/review_campaign_pro.py`。",
        "没有重建刚清理的 Swift/模拟器缓存，没有修改运行时规则、奖励或存档。"]
    (OUT / "REVIEW.md").write_text("\n".join(lines) + "\n")
    print(json.dumps({"audited_pairs": len(pairs), "medicine_used": sum(s["doses"] for s in summary),
                      "planned_new_runs": len(plan), "executed_new_runs": 0}, ensure_ascii=False))


if __name__ == "__main__":
    audit()
