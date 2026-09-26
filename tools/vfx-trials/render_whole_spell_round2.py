#!/usr/bin/env python3
"""Build a review page from existing evidence; never manufacture a passed result."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"output/whole-spell-round2-20260922"
plan=json.loads((ROOT/"output/jev-spell-plan-20260921/review.json").read_text())
capture=json.loads((OUT/"capture-plan.json").read_text())
before=json.loads((OUT/"before-index.json").read_text())
names={"N07A":"铜背甲兽 · 铜甲震","N07B":"铜背甲兽 · 掀甲崩","N08A":"赤蛮魔 · 赤拳灼击","N08B":"赤蛮魔 · 双拳坠焰","N09A":"绯幕先知 · 绯刃","N09B":"绯幕先知 · 交幕裁切","N10A":"金喉树蛙 · 金喉声弹","N10B":"金喉树蛙 · 扁波裂鸣","N11A":"月牙鼠 · 月牙噬","N11B":"月牙鼠 · 扫月"}
reports={p.stem:p.read_text() for p in OUT.glob("*-review.md")}
ledgers=[(p,set(p.read_text().splitlines())) for p in OUT.glob("record-*-recorded.txt")]
rows=[]
for original in plan["spells"]:
    id=original["id"]
    clips=[]
    for sample in capture["rows"]:
        if sample["id"]!=id:continue
        key=sample["key"]
        full=OUT/"after"/(key+".mp4")
        close=OUT/"after"/(key+"-close.mp4")
        if full.exists() and close.exists() and any(key in keys and p.stat().st_mtime >= max(full.stat().st_mtime,close.stat().st_mtime)-.1 for p,keys in ledgers):
            full_sha=hashlib.sha256(full.read_bytes()).hexdigest()
            close_sha=hashlib.sha256(close.read_bytes()).hexdigest()
            clips.append(dict(key=key,full="after/"+full.name+"?v="+full_sha[:12],close="after/"+close.name+"?v="+close_sha[:12],
                              sha256=dict(full=full_sha,close=close_sha),
                              closeLabel="实际受术者近景" if key.endswith("-recipient") else "受束缚主角近景" if key=="B02-persistent" else "施法者动作近景",
                              seconds=sample["frames"]/30,cues=sample["cues"],expected=sample["expected"]))
    prior=[dict(url="/"+c["clip"],name=Path(c["clip"]).stem) for c in before["clips"] if id in c["ids"] and not c["clip"].endswith("-close.mp4")]
    if id=="H00" and (ROOT/"output/basic-compact-20260922/before.mp4").exists():
        prior.insert(0,dict(url="/output/basic-compact-20260922/before.mp4",name="修改前 · 大幅普攻（本次反馈版本）"))
    group="新五恶魔" if id.startswith("N") else original["group"]
    report="minions-review" if id.startswith("N") else "hero-review" if id.startswith(("H","L")) or id=="R01" else "tower-review" if id.startswith("T") else "mainline-review" if id.startswith("M") else "bounty-review" if id.startswith("B") else "trials-review" if id.startswith("X") else "relics-review"
    rows.append(dict(id=id,name=names.get(id,original["name"]),group=group,scope=original["scope"],
                     clips=clips,before=prior,report=report,
                     boundary="独立视觉试演，非正式技能接入" if id.startswith("X") else "库内保留，未开放" if id.startswith("L") else "原生附效，未伪造独立法术录像" if id.startswith("R") and id!="R01" else "表现层重录；不代表原生结算或手机验收"))
receipts=[p.name for p in OUT.glob("*-passed.txt")]
if (OUT/"targets/formal-passed.txt").exists():receipts.append("targets/formal-passed.txt")
if (OUT/"delivery-validation.json").exists():receipts.append("delivery-validation.json")
data=dict(rows=rows,reports=reports,receipts=receipts)
template=(ROOT/"tools/vfx-trials/whole_spell_round2_template.html").read_text()
(OUT/"index.html").write_text(template.replace("__ROUND2_DATA__",json.dumps(data,ensure_ascii=False).replace("</","<\\/")))
(OUT/"delivery-index.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
print(json.dumps(dict(rows=len(rows),recorded_rows=sum(bool(r["clips"]) for r in rows),pairs=sum(len(r["clips"]) for r in rows)),ensure_ascii=False))
