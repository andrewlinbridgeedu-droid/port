#!/usr/bin/env python3
"""Labelled Unity presentation probes, independent of native damage settlement."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
rows = []

def row(key, skin, encounter, cues, expected=0, focus="enemy", seconds=4):
    actor = "hell-hound-primary" if skin == "early-hell-hound" else "clock-guard-primary"
    warm = ["early-presence:4"] if skin == "early-hell-hound" else []
    warm += ["tempo-sample:" + encounter]
    rows.append(dict(id=key, key=key, setup="wave-instances:" + actor + "@" + skin,
        actor=actor, focus=focus, warm=warm, frames=round(seconds * 30),
        expected=expected, safety=False, trial="", attack=cues[0][1],
        cues=[dict(frame=round(t * 30), command=c.replace("{actor}", actor)) for t,c in cues]))

for key, skin, encounter in [
    ("Q4", "early-hell-hound", "chapter01_q04_encounter"),
    ("D01", "stonehide", "church_tower_001"),
    ("B01", "bounty-b01", "church_bounty_b01")]:
    row(key + "-light", skin, encounter, [(.2,"enemy-light:{actor}:0.35"),
        (.55,"light-contact:{actor}:0")], focus="enemy")
    if key == "Q4":
        row(key + "-heavy", skin, encounter, [(.2,"q4-hound:charge"),
            (2.2,"q4-hound:first"),(2.2,"enemy:{actor}"),
            (2.85,"q4-hound:second"),(2.85,"enemy:{actor}"),
            (3.3,"q4-hound:opening")], expected=2,seconds=7)
    else:
        row(key + "-heavy", skin, encounter, [(.2,"enemy:{actor}:charge"),
            (2.2,"enemy:{actor}")], expected=1, seconds=5)

for number in ["02", "06", "07"]:
    row("Hero-" + number, "stonehide", "church_tower_001",
        [(.2,"skill:fool_skill_" + number + ":{actor}")], expected=1,focus="enemy")
row("Hero-basics", "stonehide", "church_tower_001",
    [(.2,"basic:{actor}"),(1.4,"basic:{actor}"),(2.6,"basic:{actor}")],
    expected=3,focus="player",seconds=4.2)
row("Hero-parry", "bounty-b01", "church_bounty_b01",
    [(.2,"masquerade:2"),(.6,"enemy-light:{actor}:0.35"),
        (.95,"light-contact:{actor}:1")], focus="player")

for r in rows:
    if r["key"] in ["D01-heavy", "B01-heavy", "Hero-02", "Hero-06", "Hero-07"]:
        r["safety"] = True
        r["attack"] = "enemy:" + r["actor"] if r["key"].endswith("heavy") else r["cues"][0]["command"]

for version in ["before-samples", "after-probes"]:
    target = root / "output/combat-tempo-20261001" / version
    target.mkdir(parents=True, exist_ok=True)
    (target / "capture-plan.json").write_text(json.dumps(dict(rows=rows),indent=2)+"\n")
print("11 presentation probes; the old build has no light-attack visual commands")
