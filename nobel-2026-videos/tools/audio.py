"""Score + narration mix for one film.

usage: python3 tools/audio.py <id>   -> build/<id>/mix.wav
The score is synthesised procedurally (pads, bells, drones, accents) and
ducked under the narration.
"""
import json, os, sys
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly, oaconvolve, butter, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 48000
CHAPTER_LEAD = 3.2

PRESETS = {
    # chords as MIDI notes; bar = seconds per chord
    "physics":    dict(chords=[[38, 50, 57, 62, 65, 69], [34, 46, 53, 58, 62, 65], [41, 53, 57, 60, 64, 69], [36, 48, 55, 60, 62, 67]],
                       bar=9.0, bell_rate=0.55, bell_up=24, bright=1700, seed=1, pad=0.9, bell=0.42, timbre=[1, .5, .28, .16, .08]),
    "chemistry":  dict(chords=[[40, 52, 59, 62, 66, 71], [36, 48, 55, 59, 64, 67], [33, 45, 52, 57, 60, 64], [35, 47, 54, 57, 63, 66]],
                       bar=8.0, bell_rate=0.7, bell_up=24, bright=1500, seed=2, pad=0.85, bell=0.45, timbre=[1, .35, .22, .1, .05]),
    "medicine":   dict(chords=[[45, 57, 61, 64, 69, 71], [42, 54, 57, 61, 64, 69], [38, 50, 57, 62, 66, 69], [40, 52, 56, 59, 64, 71]],
                       bar=8.0, bell_rate=0.6, bell_up=24, bright=1900, seed=3, pad=0.85, bell=0.38, timbre=[1, .45, .25, .12, .06], pulse=True),
    "literature": dict(chords=[[38, 50, 57, 62, 65, 69], [34, 46, 53, 58, 62, 65], [41, 48, 57, 60, 65, 69], [36, 48, 55, 59, 62, 67]],
                       bar=10.0, bell_rate=0.42, bell_up=12, bright=1300, seed=4, pad=0.8, bell=0.5, timbre=[1, .3, .15, .07, .03], piano=True),
}


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def reverb_ir(sec=3.8, seed=0):
    r = np.random.default_rng(seed)
    n = int(sec * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 6.9 / sec)
    ir = r.standard_normal((n, 2)) * env[:, None]
    # darker tail
    sos = butter(2, 5000, "low", fs=SR, output="sos")
    ir = sosfilt(sos, ir, axis=0)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))[:, None]
    return ir / np.sqrt((ir ** 2).sum(0, keepdims=True))


def pad(dur, P):
    n = int(dur * SR)
    out = np.zeros((n, 2))
    t_all = np.arange(n) / SR
    bar = P["bar"]
    k = 0
    while k * bar < dur:
        ch = P["chords"][k % len(P["chords"])]
        s0 = int(k * bar * SR)
        L = int((bar + 4.0) * SR)
        s1 = min(n, s0 + L)
        tt = t_all[s0:s1] - k * bar
        env = np.minimum(1, tt / 2.6) * np.minimum(1, np.maximum(0, (bar + 4.0 - tt) / 4.0))
        env = env ** 1.4
        seg = np.zeros((s1 - s0, 2))
        for j, m in enumerate(ch):
            f = mtof(m)
            amp = (0.55 if j == 0 else 0.22) / (1 + 0.15 * j)
            for ci, cents in enumerate((-6, 0, 7)):
                ff = f * 2 ** (cents / 1200)
                vib = 1 + 0.0015 * np.sin(2 * np.pi * (0.13 + 0.05 * ci) * tt + j)
                ph = 2 * np.pi * ff * np.cumsum(vib) / SR
                wave = sum(a * np.sin(h * ph + j * h) for h, a in enumerate(P["timbre"], 1))
                pan = 0.5 + 0.35 * (ci - 1) * (1 if j % 2 else -1)
                seg[:, 0] += amp * wave * (1 - pan) / 3
                seg[:, 1] += amp * wave * pan / 3
        out[s0:s1] += seg * env[:, None]
        k += 1
    sos = butter(2, P["bright"], "low", fs=SR, output="sos")
    out = sosfilt(sos, out, axis=0)
    # slow swell
    out *= (0.75 + 0.25 * np.sin(2 * np.pi * t_all / 23.0))[:, None]
    return out


def bells(dur, P):
    r = np.random.default_rng(P["seed"])
    n = int(dur * SR)
    out = np.zeros((n, 2))
    t = 2.0
    while t < dur - 1:
        k = int(t // P["bar"])
        ch = P["chords"][k % len(P["chords"])][1:]
        m = ch[r.integers(len(ch))] + P["bell_up"] + (12 if r.random() < 0.25 else 0)
        f = mtof(m)
        L = int(3.5 * SR)
        s0 = int(t * SR); s1 = min(n, s0 + L)
        tt = np.arange(s1 - s0) / SR
        if P.get("piano"):
            tone = (np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(4 * np.pi * f * tt) + 0.12 * np.sin(6 * np.pi * f * tt) * np.exp(-tt * 3)) * np.exp(-tt * 1.6)
        else:
            tone = (np.sin(2 * np.pi * f * tt) + 0.28 * np.sin(2 * np.pi * f * 2.76 * tt) * np.exp(-tt * 2) + 0.08 * np.sin(2 * np.pi * f * 5.4 * tt) * np.exp(-tt * 4)) * np.exp(-tt * 1.3)
        tone *= np.minimum(1, tt / 0.004)
        vel = 0.5 + 0.5 * r.random()
        pan = r.random()
        out[s0:s1, 0] += tone * vel * (1 - pan)
        out[s0:s1, 1] += tone * vel * pan
        t += r.exponential(1 / P["bell_rate"]) + 0.25
    return out * 0.1


def drone(dur, P):
    n = int(dur * SR); t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(int(dur / P["bar"]) + 2):
        root = P["chords"][k % len(P["chords"])][0] - 12
        s0 = int(k * P["bar"] * SR); s1 = min(n, int((k + 1) * P["bar"] * SR))
        if s0 >= n: break
        tt = t[s0:s1]
        out[s0:s1] = np.sin(2 * np.pi * mtof(root) * tt) + 0.3 * np.sin(2 * np.pi * mtof(root + 12) * tt)
    # smooth chord joins
    sos = butter(2, 120, "low", fs=SR, output="sos")
    out = sosfilt(sos, out) * (0.8 + 0.2 * np.sin(2 * np.pi * t / 7.0))
    return np.stack([out, out], 1) * 0.18


def pulse(dur):
    """a soft, slow heartbeat-like pulse (medicine)"""
    n = int(dur * SR); out = np.zeros(n)
    t = 1.0
    while t < dur:
        for off, a in ((0, 1.0), (0.28, 0.6)):
            s0 = int((t + off) * SR); L = int(0.5 * SR)
            if s0 + L >= n: break
            tt = np.arange(L) / SR
            out[s0:s0 + L] += a * np.sin(2 * np.pi * (48 + 30 * np.exp(-tt * 18)) * tt) * np.exp(-tt * 9)
        t += 1.25
    return np.stack([out, out], 1) * 0.12


def whoosh(L=1.6, seed=0):
    r = np.random.default_rng(seed)
    n = int(L * SR); tt = np.arange(n) / SR
    noise = r.standard_normal((n, 2))
    sos = butter(2, [250, 2600], "band", fs=SR, output="sos")
    x = sosfilt(sos, noise, axis=0)
    env = (tt / L) ** 2.2 * np.exp(-np.maximum(0, tt - L * 0.82) * 25)
    return x * env[:, None] * 0.35


def boom(L=3.0):
    n = int(L * SR); tt = np.arange(n) / SR
    x = np.sin(2 * np.pi * np.cumsum(36 + 50 * np.exp(-tt * 3)) / SR) * np.exp(-tt * 1.6)
    return np.stack([x, x], 1) * 0.6


def shimmer(L=4.0, base=84, seed=0):
    r = np.random.default_rng(seed)
    n = int(L * SR); out = np.zeros((n, 2))
    for i in range(14):
        s0 = int(i * 0.09 * SR); tt = np.arange(n - s0) / SR
        f = mtof(base + [0, 7, 12, 16, 19, 24, 28][i % 7])
        tone = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 1.4) * np.minimum(1, tt / 0.01)
        p = r.random()
        out[s0:, 0] += tone * (1 - p); out[s0:, 1] += tone * p
    return out * 0.06


def place(buf, x, t):
    s0 = int(t * SR)
    if s0 < 0:
        x = x[-s0:]; s0 = 0
    s1 = min(len(buf), s0 + len(x))
    if s1 > s0:
        buf[s0:s1] += x[: s1 - s0]


def main():
    vid = sys.argv[1]
    P = PRESETS[vid]
    tl = json.load(open(f"{ROOT}/build/{vid}/timeline.json", encoding="utf-8"))
    dur = tl["duration"]
    n = int(dur * SR)

    # narration
    voice = np.zeros(n)
    for b in tl["beats"]:
        for l in b["lines"]:
            w, sr = sf.read(f"{ROOT}/build/{vid}/voice/{l['wav']}", dtype="float64")
            w = resample_poly(w, SR, sr) if sr != SR else w
            place(voice, w, l["t0"])
    voice /= np.max(np.abs(voice)) + 1e-9
    # gentle presence + a whisper of room
    sos = butter(1, 90, "high", fs=SR, output="sos")
    voice = sosfilt(sos, voice)
    room = oaconvolve(voice, reverb_ir(1.1, 9)[:, 0])[:n] * 0.06
    V = np.stack([voice + room, voice + room], 1) * 0.72

    # score
    music = pad(dur, P) * P["pad"] + bells(dur, P) * P["bell"] * 4 + drone(dur, P)
    if P.get("pulse"):
        music += pulse(dur)
    # accents
    fx = np.zeros((n, 2))
    place(fx, whoosh(2.0, 1), 0.2)
    place(fx, boom(4.0), 1.4)
    place(fx, shimmer(4.0, 84, 2), 1.5)
    for i, b in enumerate(tl["beats"]):
        if b.get("chapter"):
            place(fx, whoosh(1.4, i), b["t0"] - 1.1)
            place(fx, boom(2.5) * 0.45, b["t0"] + 0.25)
            place(fx, shimmer(3.0, 79 + (i % 3) * 2, i) * 0.7, b["t0"] + 0.3)
    last = tl["beats"][-1]
    closing = last["lines"][-1]["t1"] + 0.5
    place(fx, shimmer(5.0, 72, 99) * 1.2, closing)
    place(fx, boom(5.0) * 0.5, closing)

    wet = np.stack([oaconvolve(music[:, c] + fx[:, c] * 0.6, reverb_ir(4.2, 3)[:, c])[:n] for c in range(2)], 1)
    music = music * 0.55 + wet * 0.45 + fx * 0.7

    # duck under the voice
    frame = int(0.01 * SR)
    env = np.sqrt(np.convolve(voice ** 2, np.ones(frame) / frame, "same"))
    env = np.minimum(1, env / 0.08)
    sm = np.zeros_like(env); a_att, a_rel = np.exp(-1 / (0.08 * SR)), np.exp(-1 / (0.7 * SR))
    # one-pole follower on a decimated signal for speed
    dec = env[::100]; out = np.zeros_like(dec); v = 0
    aa, ar = a_att ** 100, a_rel ** 100
    for i, x in enumerate(dec):
        v = aa * v + (1 - aa) * x if x > v else ar * v + (1 - ar) * x
        out[i] = v
    sm = np.interp(np.arange(n), np.arange(len(out)) * 100, out)
    gain = 1.0 - 0.74 * sm
    music *= gain[:, None]
    # fades
    t = np.arange(n) / SR
    fade = np.minimum(1, t / 2.5) * np.minimum(1, (dur - t) / 4.0)
    music *= fade[:, None]
    # levels: narration ~ -19 dBFS while speaking, score ~ -23 dBFS between lines
    sp = np.zeros(n, bool)
    for b in tl["beats"]:
        for l in b["lines"]:
            sp[int(l["t0"] * SR):int(l["t1"] * SR)] = True
    rms = lambda x: np.sqrt(np.mean(x ** 2)) + 1e-12
    V *= 10 ** (-19 / 20) / rms(V[sp])
    music *= 10 ** (-23 / 20) / rms(music[~sp])

    if os.environ.get("STEMS"):
        sf.write(f"{ROOT}/build/{vid}/stem_voice.wav", V.astype(np.float32), SR, subtype="FLOAT")
        sf.write(f"{ROOT}/build/{vid}/stem_music.wav", music.astype(np.float32), SR, subtype="FLOAT")
    mix = V + music
    peak = np.max(np.abs(mix))
    if peak > 0.97:
        mix *= 0.97 / peak
    sf.write(f"{ROOT}/build/{vid}/mix.wav", mix.astype(np.float32), SR, subtype="FLOAT")
    print(f"{vid}: mix {dur:.1f}s peak {peak:.2f}")


if __name__ == "__main__":
    main()
