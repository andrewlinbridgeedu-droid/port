#!/usr/bin/env python3
"""Deterministic presentation cues, not a replacement native combat simulation."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/whole-spell-round2-20260922"
P = "clock-guard-primary"
S = "clock-guard-secondary"
rows = []


def wave(skin="archivist", count=1, tower=False):
    ids = [P, S, "clock-guard-third", "clock-guard-fourth"]
    return ("church-tower:" if tower else "wave-instances:") + ",".join(
        i + ("@" + skin if skin else "") for i in ids[:count]
    )


def add(id, setup, command, *, prep=None, seconds=3.6, expected=1, actor=P,
        warm=(), extra=(), variant="", focus="enemy", attack_at=None, safety=True):
    attack_at = (1.2 if prep else .2) if attack_at is None else attack_at
    cues = [{"frame": round(attack_at * 30), "command": command}]
    if prep:
        cues.insert(0, {"frame": 3, "command": prep})
    cues += [{"frame": round(t * 30), "command": c} for t, c in extra]
    rows.append(dict(id=id, key=id + ("-" + variant if variant else ""), setup=setup,
                     frames=round(seconds * 30), expected=expected, actor=actor,
                     focus=focus, warm=list(warm), cues=cues, attack=command,
                     safety=safety and expected == 1, trial=""))


for n in ["00", "01", "04", "05", "06", "07", "08", "10", "02", "09"]:
    id = ("L" if n in ["02", "09"] else "H") + n
    add(id, wave(), "basic:" + P if n == "00" else "skill:fool_skill_" + n + ":" + P,
        focus="player", seconds=2.5 if n == "00" else 3.7)
add("H01", wave(count=2), "skill:fool_skill_01:" + P, variant="dual", focus="player",
    warm=["skill-targets:" + P + "|" + S])
add("H00", wave(), "basic:" + P, variant="followup-basic", focus="player",
    seconds=3.3, expected=3, extra=[(.8,"basic:"+P),(1.4,"basic:"+P)], safety=False)
add("H00", wave(), "basic:" + P, variant="followup-skill", focus="player",
    seconds=3.6, expected=2, extra=[(.8,"skill:fool_skill_07:"+P)], safety=False)
add("H10", wave(count=4), "skill:fool_skill_10:" + P, variant="four", focus="player",
    warm=["skill-targets:" + P + "|" + S + "|clock-guard-third|clock-guard-fourth"])
add("H04", wave(), "skill:fool_skill_04:" + P, variant="recipient", focus="enemy", seconds=3.7)
add("H10", wave(count=4), "skill:fool_skill_10:" + P, variant="recipient", focus="enemy", seconds=3.7,
    warm=["skill-targets:" + P + "|" + S + "|clock-guard-third|clock-guard-fourth"])
add("R01", wave(), "masquerade:2", focus="player", expected=0, seconds=3.2,
    extra=[(1.1, "masquerade-hit:1"), (2, "masquerade-hit:0")])
add("R01", wave(), "masquerade:1", focus="player", expected=0, seconds=5,
    variant="expire")

def enemy(id, skin, intent="", **kw):
    add(id, wave(skin), "enemy:" + P + (":" + intent if intent else ""), **kw)

enemy("M01", "")
enemy("M02", "", "guard")
enemy("M03", "fog-ghost", seconds=4.6)
enemy("M03", "crimson-ghost", variant="red", seconds=4.6)
add("M04", "wave-instances:" + P + "@fog-ghost," + S + "@crimson-ghost",
    "enemy:" + S, actor=S, seconds=4.6)
for id, mode in [("M05", 3), ("M06", 4)]:
    add(id, "wave-instances:hell-hound-primary@early-hell-hound", "enemy:hell-hound-primary",
        warm=["early-presence:" + str(mode)] + (["q4-hound:probe"] if mode == 4 else []),
        actor="hell-hound-primary", seconds=4.6)
add("M07", "wave-instances:hell-hound-primary@early-hell-hound", "q4-hound:first",
    prep="q4-hound:charge", warm=["early-presence:4"], actor="hell-hound-primary",
    attack_at=2.2, seconds=7.0, expected=2, safety=False,
    extra=[(2.2,"enemy:hell-hound-primary"),(4.5,"q4-hound:second"),(4.5,"enemy:hell-hound-primary")])
for id, count in [("M08", 0), ("M09", 1)]:
    add(id, "wave-instances:hell-hound-primary", "enemy:hell-hound-primary",
        actor="hell-hound-primary", seconds=4.6,
        warm=["@advance-enemy:hell-hound-primary"] * count)
add("M10", "chapter-thirty:19", "emerald-poison:3", expected=0, seconds=4.0,
    actor="hell-hound-primary", extra=[(2,"emerald-poison:6")])
add("M11", "chapter-thirty:19", "enemy:hell-hound-primary", prep="encore-charge",
    extra=[(1.2,"emerald-spell:burst"),(1.2,"encore-release")], actor="hell-hound-primary", seconds=5)
add("M12", wave(), "archive-state:guard", expected=0, seconds=3.4,
    extra=[(2.6,"archive-state:recover")])
for skin, a, b in [("archivist","M13","M14"),("matriarch","M23","M24"),
                   ("executor","M26","M27"),("chronarch","M30","M31")]:
    enemy(a, skin, seconds=4.6)
    enemy(b, skin, warm=["@advance-enemy:" + P], seconds=4.6)
setup="wave-instances:clock-core-primary,"+P
add("M15",setup,"enemy:clock-core-primary",actor="clock-core-primary")
add("M16",setup,"enemy:clock-core-primary:repair_guard:"+P,actor="clock-core-primary",
    extra=[(1.4,"enemy-heal:"+P)])
add("M16",setup,"enemy:clock-core-primary:repair_guard:"+P,actor="clock-core-primary",focus=P,variant="recipient",
    extra=[(1.4,"enemy-heal:"+P)])
add("M17","wave-instances:memory-leech-primary","enemy:memory-leech-primary",
    actor="memory-leech-primary",seconds=11,expected=3,safety=False,
    extra=[(3.7,"enemy:memory-leech-primary"),(7.2,"enemy:memory-leech-primary")])
add("M18","wave-instances:memory-leech-primary","enemy:memory-leech-primary:name_devour",
    actor="memory-leech-primary",prep="leech-charge:charge",seconds=5.7)
enemy("M19","scribe","fortify")
enemy("M20","scribe","calibrate")
enemy("M21","scribe",seconds=4.6)
enemy("M22","","thirteenth_charge",seconds=5.2)
for id, skin in [("M25","rescue"),("M28","adjudicator"),("M29","convoy")]:
    enemy(id,skin,seconds=4.6)

tower = [
    ("T11","stonehide","guard",None,0),
    ("T12","stonehide","archive_slam","charge",1),
    ("T21","saltmaw","tower_poison","tower_sac_charge",1),
    ("T22","saltmaw","tower_salt_spike","tower_sac_charge",1),
    ("T31","shellback","tower_mend","tower_mend_charge",1),
    ("T32","shellback","tower_short_pounce",None,1),
    ("T41","ironclaw","tower_cut_first","tower_blade_charge",1),
    ("T42","ironclaw","tower_cut_second","tower_blade_charge",1),
    ("T43","ironclaw","tower_heavy_cut","tower_raised_blade",1),
    ("T51","frilled-naga","tower_empower","tower_crown_charge",1),
    ("T52","frilled-naga","tower_sound_arrow","tower_crown_charge",1),
    ("T61","boneclaw","tower_piercing_claw","tower_claw_charge",1),
    ("T62","boneclaw","tower_tail_sweep","tower_claw_charge",1),
    ("T63","boneclaw","tower_heavy_claw","tower_claw_charge",1),
]
for id,skin,attack,prep,expected in tower:
    duration={"guard":3,"charge":2,"tower_sac_charge":2,"tower_mend_charge":2,"tower_crown_charge":2,"tower_blade_charge":1.6,"tower_raised_blade":3.2,"tower_claw_charge":3.5}.get(prep,0)
    at=duration+.2 if prep else .2
    add(id,"church-tower:"+P+"@"+skin+","+S+"@stonehide",
        "enemy:"+P+":"+attack+(":"+S if attack in ["tower_mend","tower_empower"] else ""),
        prep="enemy:"+P+":"+prep if prep else None, expected=expected,attack_at=at,
        seconds=6.3 if id=="T12" else 3.5 if id=="T11" else at+2.5,
        extra=[(at+.9,"enemy-heal:"+S)] if attack=="tower_mend" else
              [(at+.9,"church-status:empowered:"+S)] if attack=="tower_empower" else
              [(at+.9,"church-status:poison:1")] if attack=="tower_poison" else
              [(2.4,"enemy:"+P+":recover")] if id=="T11" else [])
    if id=="T51":
        rows.append(dict(rows[-1],key="T51-recipient",focus=S))
for id,skin,stem in [("N07","copperback","copperback"),("N08","crimson-brute","brute"),
                     ("N09","veil-oracle","veil"),("N10","golden-throat","throat"),
                     ("N11","moonfang","moonfang")]:
    for suffix,attack,charge in [("A","first","charge"),("B","second","charge2")]:
        add(id+suffix,"church-tower:"+P+"@"+skin,
            "enemy:"+P+":tower_"+stem+"_"+attack,
            prep="enemy:"+P+":tower_"+stem+"_"+charge,attack_at=2.4 if suffix=="A" else 3.0,seconds=4.5 if suffix=="A" else 5.1)

for id,skin,intent,prep,expected in [
    ("B01","bounty-b01","ambush","charge",1),
    ("B02","bounty-b02","bind","bounty_bind_charge",1),
    ("B03A","bounty-b03","strike",None,1),
    ("B03B","bounty-b03","heavy_strike","charge",1),
    ("B04","bounty-b04","overwrite","bounty_copy_charge",1),
    ("B05A","bounty-b05","strike",None,1),
    ("B05B","bounty-b05","silk_bind","charge",1),
    ("B06G","bounty-b06","guard",None,0),
    ("B06H","bounty-b06","heavy_strike","charge",1),
]:
    enemy(id,skin,intent,prep="enemy:"+P+":"+prep if prep else None,expected=expected,
          attack_at=3.2 if prep else .2,seconds=5.7 if prep else 4,
          extra=[(3.4,"enemy:"+P+":recover")] if id=="B06G" else [])
add("B05A",wave("bounty-b05"),"enemy:"+P+":strike",variant="alternating",expected=2,seconds=6.5,
    extra=[(3.0,"enemy:"+P+":strike")],safety=False)
add("B02",wave("bounty-b02"),"church-status:bindings:"+P,variant="persistent",expected=0,seconds=6.2,focus="player",
    extra=[(5.2,"church-status:bindings:")])
add("B03S",wave("ghost"),"church-status:escorted:"+P,expected=0,seconds=4.8,
    extra=[(3.6,"church-status:escorted:")])
enemy("B03E","ghost",seconds=4.6)
for id,style in [("X01","Phoenix"),("X02","Thunder"),("X03","Rift")]:
    add(id,wave("stonehide",3,True),"",expected=0,focus="player",seconds=3.8,safety=False)
    rows[-1]["trial"]=style

OUT.mkdir(parents=True,exist_ok=True)
(OUT/"capture-plan.json").write_text(json.dumps({"rows":rows},ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"clips":len(rows),"unique_rows":len({r['id'] for r in rows}),
                  "frames_per_view":sum(r['frames'] for r in rows)},ensure_ascii=False))
