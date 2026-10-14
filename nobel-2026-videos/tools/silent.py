"""Timeline for a film without narration: every on-screen line is held long
enough to read and snapped to the music's bar grid.

usage: python3 tools/silent.py <id>   -> build/<id>/timeline.json
"""
import json, math, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAP = 0.3  # caption off-time before the next line


def read_seconds(s):
    """Reading time for Chinese captions: characters / 4.5 + 1.5 s (Latin and digits count half)."""
    cjk = len(re.findall(r"[一-鿿]", s))
    other = len(re.findall(r"[A-Za-z0-9]", s))
    return (cjk + other * 0.5) / 4.5 + 1.5


def main():
    vid = sys.argv[1]
    S = json.load(open(f"{ROOT}/scripts/{vid}.json", encoding="utf-8"))
    beat = 60 / S.get("bpm", 96)
    bar = beat * 4
    half = bar / 2
    t = 0.0
    closing_at = None
    beats = []
    for b in S["beats"]:
        t0 = t
        if b.get("leadBars"):
            t += b["leadBars"] * bar
        elif b.get("chapter"):
            t += bar                      # one bar for the chapter card
        lines = []
        for k, line in enumerate(b["lines"]):
            text = line if isinstance(line, str) else line["t"]
            need = max(read_seconds(text) if text else 0, (line.get("minBars", 0) * bar) if isinstance(line, dict) else 0, bar)
            dur = math.ceil(need / half - 1e-6) * half
            lines.append({"k": k, "text": text, "t0": round(t, 4), "t1": round(t + dur - GAP, 4)})
            t += dur
        t = math.ceil(t / bar - 1e-6) * bar   # every section ends on a bar line
        if b["scene"] == "finale":
            closing_at = t                     # the closing card lands on a downbeat
        t += b.get("tailBars", 0) * bar
        beats.append({"scene": b["scene"], "chapter": b.get("chapter"), "cut": b.get("cut", False),
                      "t0": round(t0, 4), "t1": round(t, 4), "lines": lines})
    # captions with no text still drive the scene cues but draw nothing
    tl = {"id": vid, "silent": True, "captions": "silent", "bpm": S.get("bpm", 96), "chapterLead": bar,
          "fadeIn": 0.25, "duration": round(t, 4), "beats": beats}
    if closing_at is not None:
        tl["closingAt"] = round(closing_at, 4)
    os.makedirs(f"{ROOT}/build/{vid}", exist_ok=True)
    json.dump(tl, open(f"{ROOT}/build/{vid}/timeline.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{vid}: {sum(len(b['lines']) for b in beats)} lines, {t:.1f}s = {t / bar:.1f} bars at {tl['bpm']} bpm")


if __name__ == "__main__":
    main()
