"""Summarise a ProgressionSim output folder: summary.csv and summary.md."""
import csv
import json
import sys
from pathlib import Path

folder = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
runs = json.loads((folder / "runs.json").read_text())
gates = json.loads((folder / "gate-map.json").read_text())

columns = ["policy", "profile", "startOffset", "finalMission", "stuckAt", "days", "minutesTotal", "minutesMain",
           "minutesTower", "minutesBounty", "minutesPostal", "mainLosses", "salvesUsed", "postalJobs", "towerFloor",
           "bounties", "copper"]
rows = []
for r in runs:
    m = r["minutes"]
    rows.append([r["policy"], r["profile"], r["startOffset"], r["finalMission"], r.get("stuckAt", ""), r["days"],
                 round(sum(m.values()), 1), m.get("main", 0), m.get("tower", 0), m.get("bounty", 0), m.get("postal", 0),
                 r["losses"].get("main", 0), r["salvesUsed"], r["postalJobs"], r["towerFloor"],
                 len(r["bountiesCleared"]), r["copper"]])
with open(folder / "summary.csv", "w", newline="") as f:
    csv.writer(f).writerows([columns] + rows)

lines = ["| 策略 | 熟练 | 起始日 | 结果 | 总分钟 | 主线 | 塔 | 通缉 | 邮务 | 主线败 | 用药 | 塔层 | 通缉案 |",
         "|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
for row in rows:
    result = f"卡在 Q{row[4]}" if row[4] else "通关"
    lines.append(f"| {row[0]} | {row[1]} | {row[2]} | {result} | {row[6]} | {row[7]} | {row[8]} | {row[9]} | {row[10]} | {row[11]} | {row[12]} | {row[14]} | {row[15]} |")
lines += ["", "| 熟练 | 不靠教会装备过不去的关（所需最低塔层 / 当时开放到 / 只有通缉遗落物能否过） |", "|---|---|"]
for profile in ["high", "medium", "low"]:
    need = [f"Q{g['mission']}: F{g['minTowerFloor'] if g.get('minTowerFloor') is not None else '>100'} / F{g['towerFloorOpenAtThisPoint']} / {'能' if g['winsWithAllBountyRelics'] else '不能'}"
            for g in gates if g["profile"] == profile and not g["winsWithoutChurchGear"]]
    lines.append(f"| {profile} | {'；'.join(need) or '无'} |")
hinted = [row for row in rows if row[0] == "hinted"]
if hinted:
    lines += ["", "验收第 4 条（按提示补支线：支线 = 塔 + 通缉，不含邮务）", "",
              "| 熟练 | 起始日 | 结果 | 主线 | 支线 | 支线/主线 |", "|---|---:|---|---:|---:|---:|"]
    for row in hinted:
        side = round(row[8] + row[9], 1)
        ratio = f"{side / row[7]:.2f}" if row[7] else "-"
        lines.append(f"| {row[1]} | {row[2]} | {'卡在 Q' + str(row[4]) if row[4] else '通关'} | {row[7]} | {side} | {ratio} |")
# Daily pacing: finish day, the longest day, and the finish day if each day is capped at
# two hours (overflow carries to the next day; an approximation of spreading the work).
CAP = 120
def capped_days(by_day):
    carry = 0.0
    for minutes in by_day:
        carry = max(0.0, minutes + carry - CAP)
    return len(by_day) + int(-(-carry // CAP))
paced = [r for r in runs if r["policy"] in ("hinted", "all", "completionist") and "minutesByDay" in r]
if paced:
    lines += ["", f"按天推进（第 N 天开放第 N 关；单日上限按 {CAP} 分钟折算）", "",
              "| 策略 | 熟练 | 起始日 | 结果 | 打完是第几天 | 单日最长（分钟） | 超过 2 小时的天数 | 每天 ≤2 小时时第几天打完 |",
              "|---|---|---:|---|---:|---:|---:|---:|"]
    for r in paced:
        by_day = r["minutesByDay"]
        result = f"卡在 Q{r['stuckAt']}" if r.get("stuckAt") else "通关"
        lines.append(f"| {r['policy']} | {r['profile']} | {r['startOffset']} | {result} | {r['days']} | {max(by_day):.0f} | "
                     f"{sum(1 for m in by_day if m > CAP)} | {capped_days(by_day)} |")
sourced = [r for r in runs if r["policy"] in ("all", "completionist") and "copperBySource" in r]
if sourced:
    lines += ["", "铜币来源与工坊（J0 按单递减；工坊卖给每天 60 铜的 NPC 订单，含底料成本前）", "",
              "| 策略 | 熟练 | 起始日 | 主线 | 塔 | 通缉 | 邮务 J0 | 工坊销售 | 工坊底料 | 自熬止痛膏用掉 | 工坊分钟/天 | 章末铜 |",
              "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for r in sourced:
        src, ws = r["copperBySource"], r["workshop"]
        per_day = r["minutes"].get("workshop", 0) / max(1, r["days"])
        lines.append(f"| {r['policy']} | {r['profile']} | {r['startOffset']} | {src.get('main', 0)} | {src.get('tower', 0)} | "
                     f"{src.get('bounty', 0)} | {src.get('postal', 0)} | {src.get('workshop', 0)} | {ws['baseStockCopper']} | "
                     f"{ws['salvesUsedFromStock']} | {per_day:.1f} | {r['copper']} |")
(folder / "summary.md").write_text("\n".join(lines) + "\n")
print("\n".join(lines))
