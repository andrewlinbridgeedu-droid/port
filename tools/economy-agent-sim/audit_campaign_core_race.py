"""Exact race probabilities, exhaustive reducer oracle, participation/supply caps.

No invented combat results; Bernoulli probabilities are explicit assumptions.
"""
from collections import Counter
from fractions import Fraction as F
import hashlib
import itertools
import json
from pathlib import Path

from campaign_core_race import Result, start_race, settle_wave, exact_probabilities

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/development/world-campaign-prototype-20260927/core-race-review"
PS = (F(7, 20), F(1, 2), F(13, 20))

# Manually transcribed rounded Pro rows, order: A exclusive, B exclusive, both, neither.
# Population repetitions share exactly the same underlying cap pairs.
PRO = {
    (1, 2, 2): [(32.4, 32.4, 17.4, 17.9), (31.2, 31.2, 31.2, 6.2), (25.5, 25.5, 47.4, 1.5)],
    (1, 2, 1): [(37.5, 22.7, 12.2, 27.5), (37.5, 25, 25, 12.5), (30.7, 22.7, 42.3, 4.3)],
    (1, 3, 3): [(36.4, 36.4, 19.6, 7.5), (32.8, 32.8, 32.8, 1.6), (25.9, 25.9, 48.1, .2)],
    (1, 3, 2): [(38.6, 32.4, 17.4, 11.6), (34.4, 31.2, 31.2, 3.1), (26.5, 25.5, 47.4, .5)],
    (4, 5, 5): [(5.2, 5.2, .2, 89.5), (16, 16, 2, 66), (28.9, 28.9, 9.4, 32.7)],
    (4, 5, 4): [(5.3, 1.5, 0, 93.2), (17.6, 5.9, .4, 76.2), (35.2, 14.7, 3.2, 47)],
    (4, 6, 6): [(10.8, 10.8, .6, 77.9), (26.3, 26.3, 4.4, 43.1), (36.7, 36.7, 14.2, 12.5)],
    (4, 6, 5): [(11.2, 5.2, .2, 83.5), (28.7, 16, 2, 53.3), (41.4, 28.9, 9.4, 20.2)],
}


def as_row(caps, p_a, p_b, required=4):
    p = exact_probabilities(caps, p_a, p_b, required)
    return {"caps": list(caps), "required": required, "p_a": float(p_a), "p_b": float(p_b),
            "outcomes": {k: float(v) for k, v in p.items()},
            "rational_outcomes": {k: str(v) for k, v in p.items()},
            "npc_A_dead": float(p["B"] + p["both"]),
            "npc_B_dead": float(p["A"] + p["both"])}


def exhaustive_oracle(caps):
    # Count all binary input tapes via the actual reducer. The DP above never
    # calls this reducer. Unused future tape bits integrate out to probability 1.
    tally = Counter()
    roster = {f"{s}{i}": s for s in "AB" for i in range(1, 7)}
    for tape in itertools.product((0, 1), repeat=sum(caps)):
        a, b = tape[:caps[0]], tape[caps[0]:]
        state = start_race("oracle", caps, roster)
        while state.outcome is None:
            w = state.wave
            results = [Result(side, f"{side}{w}", "success" if seq[w - 1] else "defeat")
                       for side, seq in zip("AB", (a, b)) if w <= len(seq)]
            state = settle_wave(state, w, results)
        tally[(sum(a), sum(b), state.outcome, len(state.used_accounts))] += 1
        assert len(state.used_accounts) == len(set(state.used_accounts)) <= sum(caps)
        if state.outcome in ("A", "both"):
            assert state.breaches[0] == 4
        if state.outcome in ("B", "both"):
            assert state.breaches[1] == 4
    return tally


def run():
    pro_rows = []
    for (required, a, b), expected_rows in PRO.items():
        for p, expected in zip(PS, expected_rows):
            r = as_row((a, b), p, p, required)
            errors = [abs(100 * r["outcomes"][k] - v)
                      for k, v in zip(("A", "B", "both", "neither"), expected)]
            assert max(errors) <= .051, (required, a, b, p, errors)
            r["max_pro_rounding_error_percentage_points"] = max(errors)
            pro_rows.append(r)

    verified, sequences = [], 0
    for caps in itertools.product((4, 5, 6), repeat=2):
        tally = exhaustive_oracle(caps)
        sequences += sum(tally.values())
        for pa, pb in itertools.product(PS, repeat=2):
            probabilities = {k: F(0) for k in ("A", "B", "both", "neither")}
            mean_starts = F(0)
            for (na, nb, result, starts), count in tally.items():
                weight = count * pa**na * (1 - pa)**(caps[0] - na) * pb**nb * (1 - pb)**(caps[1] - nb)
                probabilities[result] += weight
                mean_starts += starts * weight
            assert probabilities == exact_probabilities(caps, pa, pb), (caps, pa, pb)
            r = as_row(caps, pa, pb)
            r["mean_started_attempts"] = float(mean_starts)
            # Upper bound if every started contender consumes the full 3-dose kit.
            r["expected_doses_upper_bound"] = float(3 * mean_starts)
            verified.append(r)

    attendance = []
    for fill in (F(1, 2), F(3, 4), F(1)):
        r = as_row((6, 6), fill / 2, fill / 2)
        r.update(fill_probability=float(fill), conditional_win_probability=.5)
        attendance.append(r)
    p_lo = exact_probabilities((6, 6), PS[0], PS[0])
    p_hi = exact_probabilities((6, 6), PS[2], PS[2])
    correlated = {k: float((p_lo[k] + p_hi[k]) / 2) for k in p_lo}
    data = {
        "status": "offline_policy_and_probability_validation_not_real_combat_or_live_game",
        "pro_transcribed_rows_checked": pro_rows,
        "binary_tapes_enumerated": sequences, "dp_oracle_comparisons": len(verified),
        "matrix": verified, "attendance_sensitivity": attendance,
        "shared_difficulty_mixture": {"assumption": "50% shared p=.35, 50% shared p=.65, conditionally independent", "outcomes": correlated},
        "participation": [{"participants": n, "max_core_people": 12, "maximum_fraction": 12/n,
                           "max_doses_if_three_each": 36} for n in (20, 100, 400)],
        "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [OUT / "PRO_REPLY.txt", Path(__file__), Path(__file__).with_name("campaign_core_race.py"),
                      Path(__file__).with_name("test_campaign_core_race.py")]},
    }
    (OUT / "audit.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    lines = ["# 四层核心突破：独立复算与离线规则验证", "",
        "来源：用户粘贴的第二轮 Pro 回复。此轮不访问浏览器、不改变 Swift 战斗或真实资产。概率全部基于假设，不是真人胜率。",
        "", "## 概率表核对", "",
        "采用有理数吸收状态动态规划，双方同一轮同时结算，任一达到门槛后停止所有后续轮次。人工转录 Pro 的24个独立参数行，独占/双死/无死亡四结果逐项在0.051个百分点舍入差以内。重复的100/400人行不算新实验。",
        "", "|门槛|机会 A/B|单次 p|A独占|B独占|双死|无死亡|", "|---:|---|---:|---:|---:|---:|---:|"]
    for r in pro_rows:
        lines.append(f'|{r["required"]}|{r["caps"][0]}/{r["caps"][1]}|{r["p_a"]:.0%}|' + "|".join(f'{r["outcomes"][k]:.4%}' for k in ("A", "B", "both", "neither")) + "|")
    lines += ["", "## 独立实现交叉验证", "",
        f"离线不可变状态机逐条枚举 {sequences:,} 条成功/失败输入序列；4/5/6机会的9种组合，每种再对照两方35/50/65%的9种胜率，共 {len(verified)} 个概率组合，与独立DP完全相等。",
        "这证明此离线聚合算法与给定假设一致，不证明真实战斗难度、抽选公平性、权威服务器防重放或经济平衡。",
        "状态机验证：同轮双方齐备再结算、同账号失败也占用一次机会、异阵营/重复账号拒绝、无候选不生成替身、同结果重放幂等、冲突/迟到世界结果拒绝、4个不同成功账号才改变人物状态。",
        "", "## 填位不足的敏感性", "",
        "假设每个战役机会在全部替补结束后能成功开战的概率为fill；开战后胜率50%。未填位计失败机会，仅作独立假设敏感性。",
        "", "|填位概率|任一独占|双死|无死亡|", "|---:|---:|---:|---:|"]
    for r in attendance:
        o = r["outcomes"]
        lines.append(f'|{r["fill_probability"]:.0%}|{o["A"]+o["B"]:.4%}|{o["both"]:.4%}|{o["neither"]:.4%}|')
    lines += ["", "共同难度相关性算例：一半战役所有人的条件p=.35，另一半p=.65，平均仍为.5。", 
        "其双死概率为 {:.4%}、无死亡 {:.4%}；不是固定独立p=.5时的4.3945%/43.0664%。".format(correlated["both"], correlated["neither"]),
        "真人技能异质性、团队学习与共同网络故障会使简单IID表偏离；此算例只演示不能直接把个人平均胜率带入。",
        "", "## 核心参与和物品需求上限", "",
        "|参战人数|最多核心世界贡献者|占比上限|每人最多3药的总药量上限|", "|---:|---:|---:|---:|"]
    for r in data["participation"]:
        lines.append(f'|{r["participants"]}|12|{r["maximum_fraction"]:.0%}|36|')
    mid = next(r for r in verified if r["caps"] == [6, 6] and r["p_a"] == r["p_b"] == .5)
    lines += ["", f'满额6/6、p=.5时，考虑提前结束，平均开始 {mid["mean_started_attempts"]:.4f} 场；若每场全用3药，期望药量上界为 {mid["expected_doses_upper_bound"]:.4f} 瓶。实际用药还可能更少。',
        "这是单战役核心战的上界，不包含外围或练习；后两者没有真实使用数据前不能凭空补大需求。12人名额也不能代表其他388人的核心参与感已解决。",
        "", "## 工程边界", "",
        "`campaign_core_race.py` 只接收上游已关窗、已验证的批次结果；未实现选人、签发票据、网络认证、延迟宽限、独立账号识别、永久NPC存储、Unity/UI或真实战斗。",
        "失败/超时消耗账号世界机会；未开战者可在上游替补，截止未填位消耗阵营机会。这是本地候选补充，不声称Pro已核定。",
        "", "复现：", "```sh", "PYTHONDONTWRITEBYTECODE=1 python3 tools/economy-agent-sim/audit_campaign_core_race.py",
        "PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/economy-agent-sim -p 'test_campaign_core_race.py' -v", "```",
        "完整矩阵、精确分数、源文件散列和输入原文均保存在本目录。"]
    (OUT / "REVIEW.md").write_text("\n".join(lines) + "\n")
    print(json.dumps({"pro_rows_verified": len(pro_rows), "binary_tapes": sequences,
                      "exact_comparisons": len(verified), "midpoint": mid, "attendance": attendance}, ensure_ascii=False))


if __name__ == "__main__":
    run()
