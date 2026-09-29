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
    lines += ["", "铜币来源与工坊（J0 和无名残余按单递减；工坊卖给 NPC 订单，含底料成本前）", "",
              "| 策略 | 熟练 | 起始日 | 主线 | 塔 | 通缉 | 邮务 J0 | 工坊销售 | 事件 | 残余 | 街坊 | 工坊底料 | 自熬止痛膏用掉 | 章末铜 |",
              "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for r in sourced:
        src, ws = r["copperBySource"], r["workshop"]
        lines.append(f"| {r['policy']} | {r['profile']} | {r['startOffset']} | {src.get('main', 0)} | {src.get('tower', 0)} | "
                     f"{src.get('bounty', 0)} | {src.get('postal', 0)} | {src.get('workshop', 0)} | {src.get('event', 0)} | "
                     f"{src.get('remnant', 0)} | {src.get('errand', 0)} | {ws['baseStockCopper']} | "
                     f"{ws['salvesUsedFromStock']} | {r['copper']} |")
daily = [r for r in runs if r["policy"] in ("all", "completionist") and "daily" in r]
if daily:
    names = {"casualty-wave": "伤患潮", "pump-station": "泵站", "harbor-blockade": "封锁", "workshop-foundation": "奠基"}
    marks = {"succeeded": "成", "failed": "败", "running": "进行中", "upcoming": "未到"}
    lines += ["", "每日内容（街坊委托、无名残余、世界事件；分钟为机器人战斗加假设的走动对话时间，按全局天数平均）", "",
              "| 策略 | 熟练 | 起始日 | 街坊委托 | 解锁小故事 | 残余案 | 事件胜场 | 事件结果 | 工坊 | 街坊 | 残余 | 事件 | 平均每天 | 单日最长 |",
              "|---|---|---:|---:|---:|---:|---|---|---:|---:|---:|---:|---:|---:|"]
    for r in daily:
        d, m, days = r["daily"], r["minutes"], max(1, r["days"])
        wins = "/".join(str(d["eventWins"].get(k, 0)) for k in names)
        status = "、".join(f"{v}{marks.get(d['eventStatus'].get(k, ''), '?')}" for k, v in names.items())
        per = lambda key: f"{m.get(key, 0) / days:.1f}"
        lines.append(f"| {r['policy']} | {r['profile']} | {r['startOffset']} | {d['errands']} | {d['storiesUnlocked']} | {d['remnants']} | "
                     f"{wins} | {status} | {per('workshop')} | {per('errand')} | {per('remnant')} | {per('event')} | "
                     f"{sum(m.values()) / days:.0f} | {max(r['minutesByDay']):.0f} |")
(folder / "summary.md").write_text("\n".join(lines) + "\n")
print("\n".join(lines))
