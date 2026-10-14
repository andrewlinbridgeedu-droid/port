"""Beat-locked score for a film without narration (96 BPM, 4/4).

usage: python3 tools/score.py <id>   -> build/<id>/mix.wav

Opening: one hit per beat that matches each cut, an impact on the stagflation
stamp, a groove bar, a riser, a real silence on the last beat, and the title
lands on the next downbeat. Body: a pad that changes chord every two bars over
a quiet pulse, a whoosh into every chapter card. Ending: the opening's hits
played backwards, a second silence before it, and a final chord on the closing
card. All times come from build/<id>/timeline.json.
"""
import json, os, re, subprocess, sys
import numpy as np
import soundfile as sf
from scipy.ndimage import minimum_filter1d
from scipy.signal import oaconvolve, butter, sosfilt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from audio import SR, mtof, pad, whoosh, boom, shimmer, place, reverb_ir  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(96)

G, EM, C, D = [43, 55, 62, 66, 71, 74], [40, 52, 59, 62, 67, 71], [36, 48, 55, 59, 64, 67], [38, 50, 57, 62, 66, 69]
AM, B7 = [33, 45, 52, 57, 60, 64], [35, 47, 54, 57, 63, 66]
BRIGHT, DARK = [G, EM, C, D], [EM, C, AM, B7]
MOOD = {"phillips": DARK, "shocks": DARK}


def env_exp(L, k, attack=0.002):
    t = np.arange(int(L * SR)) / SR
    return t, np.exp(-t * k) * np.minimum(1, t / attack)


def st(x, pan=0.5):
    return np.stack([x * (1 - pan) * 2 ** 0.5, x * pan * 2 ** 0.5], 1) * 0.7


def bp(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x, axis=0)


def kick(v=1.0):
    t, e = env_exp(0.45, 9)
    f = 46 + 90 * np.exp(-t * 30)
    return st(np.sin(2 * np.pi * np.cumsum(f) / SR) * e * v)


def hat(v=1.0, L=0.06, pan=0.6):
    t, e = env_exp(L, 70)
    return st(bp(rng.standard_normal(len(t)), 6000, 14000) * e * v, pan)


def tick(v=1.0, f=2400, pan=0.5):
    t, e = env_exp(0.05, 120, 0.0005)
    return st((np.sin(2 * np.pi * f * t) + 0.6 * bp(rng.standard_normal(len(t)), 3000, 7000)) * e * v, pan)


def blip(f0, f1, v=1.0, L=0.25):
    t, e = env_exp(L, 14)
    f = f0 * (f1 / f0) ** np.minimum(1, t / 0.08)
    return st(np.sin(2 * np.pi * np.cumsum(f) / SR) * e * v)


def pluck(m, v=1.0, L=1.6, pan=0.5):
    t, e = env_exp(L, 3.2)
    f = mtof(m)
    x = sum(a * np.sin(2 * np.pi * f * h * t) * np.exp(-t * (h - 1) * 2.5) for h, a in enumerate([1, .5, .3, .15], 1))
    return st(x * e * v, pan)


def bell(m, v=1.0, L=3.0, pan=0.5):
    t, e = env_exp(L, 1.3, 0.004)
    f = mtof(m)
    x = np.sin(2 * np.pi * f * t) + 0.28 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 2) + 0.08 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 4)
    return st(x * e * v, pan)


def stab(chord, v=1.0, L=1.8, k=2.2, cutoff=2400):
    t, e = env_exp(L, k, 0.004)
    out = np.zeros((len(t), 2))
    for j, m in enumerate(chord):
        f = mtof(m)
        for ci, cents in enumerate((-8, 0, 8)):
            ff = f * 2 ** (cents / 1200)
            x = sum(np.sin(2 * np.pi * ff * h * t) / h for h in range(1, 7))   # bright saw-like
            out += st(x * (0.6 if j == 0 else 0.3) / 3, 0.5 + 0.3 * (ci - 1) * (1 if j % 2 else -1))
    out = sosfilt(butter(2, cutoff, "low", fs=SR, output="sos"), out, axis=0)
    return out * e[:, None] * v / len(chord) * 1.6


def bass(m, v=1.0, L=0.55):
    t, e = env_exp(L, 5, 0.006)
    f = mtof(m)
    return st((np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t)) * e * v)


def impact(v=1.0):
    t, e = env_exp(3.0, 1.8)
    low = np.tanh(2.5 * np.sin(2 * np.pi * np.cumsum(40 + 70 * np.exp(-t * 10)) / SR)) * e
    _, en = env_exp(1.2, 5)
    noise = np.zeros(len(t)); noise[: len(en)] = bp(rng.standard_normal(len(en)), 300, 9000) * en
    return (st(low * 0.9) + st(noise * 0.5, 0.5)) * v


def riser(L, v=1.0):
    t = np.arange(int(L * SR)) / SR
    u = t / L
    noise = rng.standard_normal((len(t), 2))
    lo = sosfilt(butter(2, [400, 2500], "band", fs=SR, output="sos"), noise, axis=0)
    hi = sosfilt(butter(2, [2500, 12000], "band", fs=SR, output="sos"), noise, axis=0)
    x = lo * (1 - u)[:, None] + hi * u[:, None]
    tone = np.sin(2 * np.pi * np.cumsum(mtof(55) * 2 ** (u * 2)) / SR)
    return (x * 0.5 + st(tone * 0.35)) * (u ** 2.4)[:, None] * v


def swell(L, v=1.0):
    """reverse cymbal: grows into the next downbeat"""
    return (shimmer(L, 79, 5)[::-1] * 4 + whoosh(L, 7)) * v


def main():
    vid = sys.argv[1]
    tl = json.load(open(f"{ROOT}/build/{vid}/timeline.json", encoding="utf-8"))
    dur = tl["duration"]
    beat = 60 / tl.get("bpm", 96)
    bar = beat * 4
    n = int(dur * SR)
    dry = np.zeros((n, 2))   # goes through the reverb
    fx = np.zeros((n, 2))    # mostly dry percussion
    spans = []
    for b in tl["beats"]:
        if spans and spans[-1]["scene"] == b["scene"] and not b.get("chapter"):
            spans[-1]["t1"] = b["t1"]
        else:
            spans.append(dict(scene=b["scene"], t0=b["t0"], t1=b["t1"], chapter=b.get("chapter"), lines=b["lines"]))
    S = {s["scene"]: s for s in spans}
    title, finale = S["title"]["t0"], S["finale"]["t0"]
    closing = tl.get("closingAt", dur - 10)

    # ---- opening: four bars, one hit per cut
    place(fx, kick(0.8), 0)
    place(dry, pluck(G[3] + 12, 0.9), 0)                                    # 一个家庭
    place(fx, kick(0.8), beat)
    place(dry, stab(G, 0.9, 1.2, 3.0), beat)                               # 千家万户
    place(fx, kick(0.8), 2 * beat)
    for i in range(5):                                                     # 定价：五张价签翻面
        place(fx, tick(0.55, 2200 + 180 * i, 0.2 + 0.15 * i), 2 * beat + i * 0.06)
    place(fx, kick(0.8), 3 * beat)
    place(dry, blip(500, 1300, 0.6), 3 * beat)                             # 利率：表盘一跳
    # bar 2 — the curve draws, red points burst, 滞胀 stamps on beat 3
    place(dry, bass(EM[0], 0.9, bar), bar)
    place(fx, kick(0.9), bar)
    for i in range(10):
        place(fx, tick(0.35, 1500 + 200 * i, rng.random()), bar + beat + i * 0.02)
    place(fx, impact(1.0), bar + 2 * beat)
    place(dry, stab([28, 40, 47, 52, 55], 0.8, 2.0, 1.5, 1200), bar + 2 * beat)
    # bar 3 — the tide: a groove
    place(dry, whoosh(1.2, 3) * 1.4, 2 * bar)
    for k in range(8):
        t = 2 * bar + k * beat / 2
        if k % 4 == 0: place(fx, kick(0.85), t)
        place(fx, hat(0.35 if k % 2 else 0.22), t)
        place(dry, bass([40, 40, 47, 40, 36, 36, 43, 38][k] + 12, 0.6, beat / 2 + 0.05), t)
    place(dry, bell(EM[4] + 12, 0.6, 2.5, 0.7), 2 * bar + 2 * beat)        # 如何平稳？
    # bar 4 — everything pulls into one point; riser, then a real silence on beat 4
    place(dry, riser(3 * beat, 1.0), 3 * bar)
    for k in range(12):
        place(fx, hat(0.15 + 0.03 * k, 0.04), 3 * bar + k * beat / 4)
    for k in range(3):
        place(fx, kick(0.5 + 0.15 * k), 3 * bar + k * beat)

    # ---- title: lands on bar 5's downbeat, a bell for every layer that drops
    place(fx, kick(1.0), title)
    place(fx, boom(4.0) * 1.1, title)
    place(dry, stab(G, 1.0, 3.5, 0.9), title)
    place(dry, shimmer(5.0, 84, 2) * 2.0, title)
    tp = dict(chords=[G], bar=S["title"]["t1"] - title, timbre=[1, .4, .22, .1, .05], bright=1600)
    place(dry, pad(tp["bar"] + 1.5, tp) * 0.5, title)
    for k, m in enumerate([D[4] + 12, G[4] + 12, D[5] + 12, G[5] + 12]):
        place(dry, bell(m, 0.55, 3.0, 0.3 + 0.13 * k), title + (k + 1) * 2 * beat)
    for k in range(1, 3):
        place(fx, kick(0.45), title + k * bar)

    # ---- body: pad changing every two bars over a quiet pulse
    body0, body1 = S[spans[2]["scene"]]["t0"], finale
    for sp in spans[2:-1]:
        prog = MOOD.get(sp["scene"], BRIGHT)
        P = dict(chords=prog, bar=2 * bar, timbre=[1, .4, .22, .1, .05], bright=1500 if prog is DARK else 1700)
        L = sp["t1"] - sp["t0"]
        seg = pad(L + 1.0, P)
        # soft edges so a chapter's pad hands over to the next
        e = np.minimum(1, np.arange(len(seg)) / (1.0 * SR)) * np.minimum(1, (len(seg) - np.arange(len(seg))) / (1.2 * SR))
        place(dry, seg * e[:, None] * 0.55, sp["t0"])
        # chapter card: whoosh into the downbeat, low hit, three bells across the card's bar
        place(fx, whoosh(1.4, int(sp["t0"])) * 0.9, sp["t0"] - 1.3)
        place(fx, boom(2.5) * 0.5, sp["t0"])
        for k, m in enumerate([prog[0][3], prog[0][4], prog[0][5]]):
            place(dry, bell(m + 12, 0.45, 3.0, 0.3 + 0.2 * k), sp["t0"] + k * beat)
        # pulse after the card: kick on the downbeat, shaker on the off-beats, bells on the 8th grid
        t = sp["t0"] + bar
        k = 0
        while t < sp["t1"] - 1e-6:
            if k % 8 == 0: place(fx, kick(0.32), t)
            if k % 2 == 1: place(fx, hat(0.07, 0.05, 0.35 + 0.3 * rng.random()), t)
            if rng.random() < 0.16:
                ch = prog[int((t - sp["t0"]) // (2 * bar)) % len(prog)]
                place(dry, bell(ch[1 + rng.integers(len(ch) - 1)] + 24, 0.18 + 0.15 * rng.random(), 3.0, rng.random()), t)
            t += beat / 2; k += 1
        # per-chapter accents tied to the captions
        cue = [l["t0"] for l in sp["lines"]]
        if sp["scene"] == "phillips" and len(cue) > 2:
            place(fx, impact(0.6), cue[2]); place(dry, stab([28, 40, 47, 52, 55], 0.5, 2.0, 1.5, 1200), cue[2])
        if sp["scene"] == "pricing":
            for i in range(8):
                place(fx, tick(0.18, 2000 + 120 * (i % 4), 0.3 + 0.05 * i), cue[0] + i * beat)
        if sp["scene"] == "shocks" and cue:
            place(fx, impact(0.5), cue[0])
        if sp["scene"] == "centralbank" and cue:
            place(dry, bell(G[5] + 12, 0.45, 3.0, 0.5), cue[1] if len(cue) > 1 else cue[0])

    # ---- ending: the opening backwards, a moon, a final chord
    place(fx, kick(0.9), finale)
    place(dry, blip(1300, 500, 0.6), finale)                                  # 利率
    place(fx, kick(0.8), finale + beat)
    for i in range(5):
        place(fx, tick(0.55, 2900 - 180 * i, 0.8 - 0.15 * i), finale + beat + i * 0.06)   # 定价
    place(fx, kick(0.8), finale + 2 * beat)
    place(dry, stab(G, 0.9, 1.2, 3.0), finale + 2 * beat)                    # 千家万户
    place(dry, swell(beat, 0.8), finale + 3 * beat)                          # 归一
    place(fx, kick(0.9), finale + bar)
    place(fx, boom(4.0) * 0.8, finale + bar)
    for k, m in enumerate([G[2] + 12, G[3] + 12, G[4] + 12, G[5] + 12]):
        place(dry, bell(m, 0.5, 4.0, 0.25 + 0.17 * k), finale + bar + k * 0.09)  # 以微知著
    FP = dict(chords=[G, C, EM, D], bar=2 * bar, timbre=[1, .4, .22, .1, .05], bright=1500)
    fl = closing - finale - bar
    seg = pad(fl + 1.5, FP)
    e = np.minimum(1, np.arange(len(seg)) / (1.6 * SR)) * np.minimum(1, (len(seg) - np.arange(len(seg))) / (1.5 * SR))
    place(dry, seg * e[:, None] * 0.55, finale + bar)
    t = finale + 2 * bar
    while t < closing - 1e-6:
        if rng.random() < 0.22:
            place(dry, bell(G[1 + rng.integers(5)] + 24, 0.15 + 0.12 * rng.random(), 3.0, rng.random()), t)
        t += beat / 2
    place(fx, kick(0.8), closing)
    place(fx, boom(5.0) * 0.8, closing)
    place(dry, stab([31] + G, 0.8, 8.0, 0.45, 1800), closing)
    place(dry, shimmer(6.0, 79, 99) * 2.2, closing)
    cp = dict(chords=[G], bar=dur - closing, timbre=[1, .4, .22, .1, .05], bright=1400)
    place(dry, pad(dur - closing + 1.0, cp) * 0.45, closing)

    # ---- mix
    ir = reverb_ir(3.6, 3)
    wet = np.stack([oaconvolve(dry[:, c] + fx[:, c] * 0.25, ir[:, c])[:n] for c in range(2)], 1)
    mix = dry * 0.6 + wet * 0.38 + fx * 0.85
    mix = sosfilt(butter(1, 28, "high", fs=SR, output="sos"), mix, axis=0)
    # two real silences: the last beat before the title, the last beat before the ending
    g = np.ones(n)
    for t0, t1 in ((title - beat, title), (finale - beat, finale)):
        a, b = int((t0 + 0.02) * SR), int((t1 - 0.004) * SR)
        g[a - int(0.05 * SR):a] = np.minimum(g[a - int(0.05 * SR):a], np.linspace(1, 0, int(0.05 * SR)))
        g[a:b] = 0
    mix *= g[:, None]
    t = np.arange(n) / SR
    mix *= np.minimum(1, (dur - 0.1 - t) / 2.2).clip(0, 1)[:, None]
    # web loudness (about -14 LUFS) with a peak limiter instead of squashing the whole track
    out = f"{ROOT}/build/{vid}/mix.wav"
    mix *= 0.89 / np.max(np.abs(mix))
    for _ in range(3):
        sf.write(out, mix.astype(np.float32), SR, subtype="FLOAT")
        lufs = loudness(out)
        if abs(lufs - TARGET) < 0.3:
            break
        mix = limit(mix * 10 ** ((TARGET - lufs) / 20))
    print(f"{vid}: score {dur:.1f}s, {lufs:.1f} LUFS, peak {20 * np.log10(np.max(np.abs(mix))):.1f} dBFS; "
          f"title hit {title:.2f}s, ending {finale:.2f}s, closing chord {closing:.2f}s")


TARGET = -14.0


def loudness(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"], capture_output=True, text=True)
    return float(re.findall(r"I:\s+(-?[0-9.]+) LUFS", r.stderr)[-1])


def limit(x, ceiling=0.8, look=0.004, rel=0.15):
    """look-ahead peak limiter: the gain dips just before a peak and recovers over ~rel seconds"""
    g = np.minimum(1, ceiling / (np.max(np.abs(x), 1) + 1e-9))
    g = minimum_filter1d(g, 2 * int(look * SR) + 1)
    step = 48
    dec = g[::step]; sm = np.empty_like(dec); v = 1.0
    ar = np.exp(-step / (rel * SR))
    for i, y in enumerate(dec):
        v = y if y < v else ar * v + (1 - ar) * y
        sm[i] = v
    g = np.minimum(g, np.interp(np.arange(len(g)), np.arange(len(sm)) * step, sm))
    return np.clip(x * g[:, None], -0.98, 0.98)


if __name__ == "__main__":
    main()
