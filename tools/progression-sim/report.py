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
(folder / "summary.md").write_text("\n".join(lines) + "\n")
print("\n".join(lines))
