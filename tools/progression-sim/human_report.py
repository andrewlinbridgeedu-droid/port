"""Summarise `ProgressionSim human` output: modelled activity times and human-pace days."""
import json
import sys
from pathlib import Path
from statistics import median

folder = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
timings = json.loads((folder / "timings.json").read_text())
runs = json.loads((folder / "runs.json").read_text())
paces = [p["pace"]["name"] for p in timings["paces"]]
names = {"quick": "快", "typical": "一般", "casual": "慢"}

lines = ["模拟器估算，不是真人或真机测量。", "",
         f"街上两名街坊之间平均步行 {timings['streetAverageWalkSeconds']} 秒（地图坐标、主角跑速 3.2 单位/秒、绕路系数 1.3）。", "",
         "## 每类活动一次要多久（分钟：非战斗 + 战斗 = 合计）", "",
         "| 活动 | 范围 | " + " | ".join(names.get(p, p) for p in paces) + " |",
         "|---|---|" + "---:|" * len(paces)]
by_pace = {p["pace"]["name"]: {a["activity"]: a for a in p["activities"]} for p in timings["paces"]}
for activity in [a["activity"] for a in timings["paces"][0]["activities"]]:
    cells = []
    for pace in paces:
        a = by_pace[pace][activity]
        cells.append(f"{a['nonBattleSeconds'] / 60:.1f} + {a['battleSeconds'] / 60:.1f} = **{a['totalSeconds'] / 60:.1f}**")
    lines.append(f"| {activity} | {by_pace[paces[0]][activity]['scope']} | " + " | ".join(cells) + " |")

lines += ["", "## 按天推进的整章（人的速度）", "",
          "| 速度 | 打法 | 起始日 | 结果 | 打完第几天 | 平均每天 | 中位 | 最长一天 | 超过 2 小时的天 | 不到 1 小时的天 | 全章小时 | 章末铜 |",
          "|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
for r in runs:
    by_day = r["minutesByDay"]
    total = sum(r["minutes"].values())
    result = f"卡在 Q{r['stuckAt']}" if r.get("stuckAt") else "通关"
    lines.append(f"| {names.get(r['profile'], r['profile'])} | {r['policy']} | {r['startOffset']} | {result} | {r['days']} | "
                 f"{total / max(1, r['days']):.0f} | {median(by_day):.0f} | {max(by_day):.0f} | {sum(1 for m in by_day if m > 120)} | "
                 f"{sum(1 for m in by_day if m < 60)} | {total / 60:.1f} | {r['copper']} |")

lines += ["", "## 时间花在哪（每天平均分钟，全都做，起始日 0）", ""]
kinds = ["newspaper", "main", "tower", "bounty", "postal", "workshop", "errand", "event", "remnant"]
labels = ["日刊", "主线", "塔", "通缉", "邮务", "工坊", "街坊", "事件", "残余"]
lines += ["| 速度 | " + " | ".join(labels) + " | 合计 |", "|---|" + "---:|" * (len(kinds) + 1)]
for r in runs:
    if r["policy"] != "all" or r["startOffset"] != runs[0]["startOffset"]:
        continue
    days = max(1, r["days"])
    cells = [f"{r['minutes'].get(k, 0) / days:.1f}" for k in kinds]
    lines.append(f"| {names.get(r['profile'], r['profile'])} | " + " | ".join(cells) + f" | {sum(r['minutes'].values()) / days:.1f} |")

# What would fill a 60- or 120-minute day: the day's content, then repeat jobs (J1/J2 in turn,
# paid through the daily taper), then card games. Averages over the chapter, all policy, offset 0.
lines += ["", "## 每天 1 小时、2 小时要怎么填（全都做之后，再用重复工作和牌局补足；按全章平均）", "",
          "| 速度 | 每天的内容 | 补到 60 分钟：J1/J2 几单 + 牌局几局 | 这些重复工作的铜 | 补到 120 分钟 | 铜 |", "|---|---:|---|---:|---|---:|"]
def fill(pace, content, target):
    a = by_pace[pace]
    jobs = [a["J1"]["totalSeconds"] / 60, a["J2"]["totalSeconds"] / 60]
    pay = [60, 80]
    left, n, copper = target - content, 0, 0
    while left > 0 and n < 60:
        cost = jobs[n % 2]
        if cost > left: break
        percent = 100 if n < 3 else 50 if n < 6 else 10
        copper += round(pay[n % 2] * percent / 100); left -= cost; n += 1
    games = max(0, int(left // (a["tavern"]["totalSeconds"] / 60)))
    return n, games, copper
for r in runs:
    if r["policy"] != "all" or r["startOffset"] != runs[0]["startOffset"]:
        continue
    content = sum(r["minutes"].values()) / max(1, r["days"])
    one, two = fill(r["profile"], content, 60), fill(r["profile"], content, 120)
    lines.append(f"| {names.get(r['profile'], r['profile'])} | {content:.0f} 分钟 | {one[0]} 单 + {one[1]} 局 | {one[2]} | {two[0]} 单 + {two[1]} 局 | {two[2]} |")
lines += ["", "敏感度：模型若把每一秒都低估了一半（所有非战斗和战斗时间都乘 2），每天的内容仍只有 "
          + "、".join(f"{names.get(r['profile'], r['profile'])} {2 * sum(r['minutes'].values()) / max(1, r['days']):.0f} 分钟"
                      for r in runs if r["policy"] == "all" and r["startOffset"] == runs[0]["startOffset"]) + "。"]

(folder / "summary.md").write_text("\n".join(lines) + "\n")
print("\n".join(lines))
