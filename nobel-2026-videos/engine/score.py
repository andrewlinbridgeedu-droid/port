"""程序化配乐与音效，并与解说混音。

用法: python3 engine/score.py <film>
输入: assets/<film>/timeline.json, build/<film>/narration.wav
输出: build/<film>/music.wav（配乐+音效）, build/<film>/mix.wav（最终混音，48 kHz 立体声）
"""
import json, os, sys
import numpy as np, soundfile as sf
import scipy.signal as sg

SR = 48000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
film = sys.argv[1]
TL = json.load(open(f'{ROOT}/assets/{film}/timeline.json'))
TOTAL = TL['total']
N = int((TOTAL + 2) * SR)
SC = {s['id']: s for s in TL['scenes']}
R = np.random.default_rng(2026)

def m2f(m): return 440.0 * 2 ** ((m - 69) / 12)
NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
def nm(s):  # 'F#3' → midi
    n = NAMES[s[0]]; i = 1
    while i < len(s) and s[i] in '#b': n += 1 if s[i] == '#' else -1; i += 1
    return n + 12 * (int(s[i:]) + 1)

class Bus:
    def __init__(self): self.x = np.zeros((N, 2), np.float32)
    def add(self, sig, t0, gain=1.0, pan=0.0):
        if sig.ndim == 1:
            l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
            sig = np.stack([sig * l, sig * r], 1)
        i = int(t0 * SR)
        if i >= N: return
        if i < 0: sig = sig[-i:]; i = 0
        n = min(len(sig), N - i); self.x[i:i + n] += sig[:n] * gain

def tvec(dur): return np.arange(int(dur * SR)) / SR
def ramp_env(n, a, r):
    e = np.ones(n, np.float32); a = int(a * SR); r = int(r * SR)
    if a: e[:a] = (1 - np.cos(np.linspace(0, np.pi, a))) / 2
    if r: e[-r:] *= (1 + np.cos(np.linspace(0, np.pi, r))) / 2
    return e

# ---------- 乐器 ----------
def pad(midis, dur, bright=.5, att=2.5, rel=3.0, detune=.0018):
    t = tvec(dur); out = np.zeros((len(t), 2), np.float32)
    for m in midis:
        f = m2f(m)
        for k, (dt, pan) in enumerate([(-detune, -.7), (0, 0), (detune, .7)]):
            ff = f * (1 + dt); sig = np.zeros(len(t), np.float32); ph = R.random(16) * 6.28
            for h in range(1, 14):
                if ff * h > 9000: break
                w = h ** -1.25 * np.exp(-(h - 1) * (1.15 - bright) * .55)
                sig += (w * np.sin(2 * np.pi * ff * h * t + ph[h])).astype(np.float32)
            lfo = 1 + .18 * np.sin(2 * np.pi * (.07 + .03 * k) * t + R.random() * 6)
            sig *= lfo
            l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
            out[:, 0] += sig * l; out[:, 1] += sig * r
    out *= ramp_env(len(t), min(att, dur * .4), min(rel, dur * .45))[:, None]
    return out / max(1, len(midis)) * .5

def bell(m, dur=5.0, glassy=1.0):
    t = tvec(dur); f = m2f(m); sig = np.zeros(len(t), np.float32)
    for r_, a, d in [(1, 1, 1), (2.0, .35, .6), (2.76, .5 * glassy, .45), (4.07, .25 * glassy, .3), (5.4, .18 * glassy, .22), (8.93, .08 * glassy, .12)]:
        sig += (a * np.sin(2 * np.pi * f * r_ * t) * np.exp(-t / (dur * .28 * d))).astype(np.float32)
    sig *= ramp_env(len(t), .004, .2)
    return sig * .35

def pluck(m, dur=3.5, bright=.55, slide=0.0):
    t = tvec(dur); f = m2f(m) * (1 + slide * np.exp(-t / .09)); phase = 2 * np.pi * np.cumsum(f) / SR
    sig = np.zeros(len(t), np.float32)
    for h in range(1, 18):
        if m2f(m) * h > 10000: break
        a = (bright ** (h - 1)) / h; dec = .9 + .45 * h
        sig += (a * np.sin(h * phase + h * .7) * np.exp(-t * dec * 3.5 / dur)).astype(np.float32)
    sig *= ramp_env(len(t), .002, .15)
    return sig * .5

def bowl(m, dur=8.0):
    t = tvec(dur); f = m2f(m); sig = np.zeros(len(t), np.float32)
    for r_, a, d in [(1, 1, 1), (2.71, .55, .7), (5.15, .3, .45), (8.4, .12, .3)]:
        beat = 1 + .25 * np.sin(2 * np.pi * (.6 + r_ * .2) * t)
        sig += (a * beat * np.sin(2 * np.pi * f * r_ * t) * np.exp(-t / (dur * .32 * d))).astype(np.float32)
    sig *= ramp_env(len(t), .01, .5)
    return sig * .3

def sub(m, dur, att=3, rel=3):
    t = tvec(dur); f = m2f(m)
    sig = (np.sin(2 * np.pi * f * t) + .25 * np.sin(4 * np.pi * f * t)).astype(np.float32)
    return sig * ramp_env(len(t), min(att, dur * .4), min(rel, dur * .4)) * .35

def band_noise(dur, lo, hi, seed=0):
    rng = np.random.default_rng(seed); x = rng.standard_normal(int(dur * SR)).astype(np.float32)
    sos = sg.butter(2, [lo, hi], 'bandpass', fs=SR, output='sos'); return sg.sosfilt(sos, x).astype(np.float32)

def sweep_noise(dur, f0, f1, q=.35, seed=1):
    """噪声扫频（呼啸声）：STFT 上移动的高斯频带"""
    rng = np.random.default_rng(seed); x = rng.standard_normal(int(dur * SR))
    f, tt, Z = sg.stft(x, SR, nperseg=2048)
    u = np.linspace(0, 1, Z.shape[1]); fc = f0 * (f1 / f0) ** u
    mask = np.exp(-(np.log(np.maximum(f[:, None], 20) / fc[None, :]) / q) ** 2)
    _, y = sg.istft(Z * mask, SR, nperseg=2048); y = y[:int(dur * SR)].astype(np.float32)
    return y / (np.abs(y).max() + 1e-9)

def whoosh(dur=1.8, up=True, seed=3):
    y = sweep_noise(dur, 180 if up else 3500, 3500 if up else 180, .45, seed)
    e = np.sin(np.linspace(0, np.pi, len(y))) ** 1.6
    return (y * e * .5).astype(np.float32)

def boom(dur=3.0):
    t = tvec(dur); f = 38 + 50 * np.exp(-t / .12); ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * np.exp(-t / .9) + .3 * band_noise(dur, 40, 300, 9) * np.exp(-t / .08)
    return (s * .8).astype(np.float32)

def riser(dur=3.0, seed=5):
    y = sweep_noise(dur, 300, 6000, .5, seed); e = np.linspace(0, 1, len(y)) ** 2.5
    return (y * e * .35).astype(np.float32)

def shimmer(dur, midis, density=6, seed=7):
    rng = np.random.default_rng(seed); out = np.zeros(int((dur + 3) * SR), np.float32)
    for k in range(int(dur * density)):
        t0 = rng.random() * dur; m = rng.choice(midis) + 24
        b = bell(m, 2.5, .6) * (.15 + .25 * rng.random()); i = int(t0 * SR); out[i:i + len(b)] += b[:len(out) - i]
    return out

def heartbeat(dur, bpm=60):
    out = np.zeros(int((dur + 1) * SR), np.float32); t = tvec(.35)
    thump = (np.sin(2 * np.pi * (52 + 30 * np.exp(-t / .03)) * t) * np.exp(-t / .07)).astype(np.float32)
    beat = 60 / bpm
    for k in range(int(dur / beat)):
        for off, g in [(0, 1), (.28, .6)]:
            i = int((k * beat + off) * SR); out[i:i + len(thump)] += thump[:len(out) - i] * g
    return out * .6

def crackle(dur, rate=18, seed=11):
    rng = np.random.default_rng(seed); out = np.zeros(int(dur * SR), np.float32)
    for k in range(int(dur * rate)):
        i = int(rng.random() * (len(out) - 600)); L = rng.integers(40, 500)
        out[i:i + L] += (rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 4)) * (.2 + .8 * rng.random())).astype(np.float32)
    sos = sg.butter(2, [900, 9000], 'bandpass', fs=SR, output='sos')
    return sg.sosfilt(sos, out).astype(np.float32) * .25

def reverb(x, rt=3.2, wet=.35, pre=.025, seed=4):
    rng = np.random.default_rng(seed); n = int(rt * 1.2 * SR); t = np.arange(n) / SR
    out = np.zeros_like(x)
    for c in range(2):
        ir = rng.standard_normal(n) * np.exp(-6.9 * t / rt)
        sos = sg.butter(1, 5000, 'lowpass', fs=SR, output='sos'); ir_dark = sg.sosfilt(sos, ir)
        mixk = np.clip(t / rt, 0, 1); ir = ir * (1 - mixk) + ir_dark * mixk
        ir = np.concatenate([np.zeros(int(pre * SR)), ir]); ir /= np.sqrt((ir ** 2).sum())
        out[:, c] = sg.fftconvolve(x[:, c], ir)[:len(x)]
    return (x * (1 - wet) + out * wet * 1.6).astype(np.float32)

# ---------- 各片乐谱 ----------
def chords_of(names): return [[nm(s) for s in c.split()] for c in names]
SPEC = {
    'physics': dict(chords=chords_of(['D2 A2 F3 C4 E4', 'A#1 F2 D3 A3 E4', 'F2 C3 A3 E4 G4', 'C2 G2 E3 D4 G4']), clen=10.0,
                    scale=[nm(s) for s in 'D5 F5 G5 A5 C6 D6 E6'.split()], bell_rate=.35, glassy=1.0, tex='wind', final='D2 A2 F3 A3 E4'),
    'chemistry': dict(chords=chords_of(['E2 B2 G3 D4 F#4', 'C2 G2 E3 B3 D4', 'A1 E2 C3 G3 B3', 'B1 F#2 A3 E4 F#4']), clen=9.0,
                      chords2=chords_of(['E2 B2 G#3 B3 F#4', 'C#2 G#2 E3 B3 E4', 'A1 E2 C#3 G#3 B3', 'B1 F#2 D#3 A3 F#4']),
                      scale=[nm(s) for s in 'E5 F#5 G5 B5 D6 E6'.split()], bell_rate=.25, glassy=.7, tex='arp', final='E2 B2 G#3 D#4 F#4'),
    'medicine': dict(chords=chords_of(['F#2 C#3 A3 E4 G#4', 'D2 A2 F#3 C#4 E4', 'A1 E2 C#3 G#3 B3', 'E2 B2 G#3 C#4 F#4']), clen=9.5,
                     scale=[nm(s) for s in 'C#5 E5 F#5 A5 B5 C#6'.split()], bell_rate=.3, glassy=.55, tex='pulse', final='A1 E2 C#3 G#3 B3 E4'),
    'literature': dict(chords=chords_of(['D2 A2 F#3 B3 E4', 'B1 F#2 D3 A3 E4', 'G1 D2 B2 F#3 A3', 'A1 E2 B2 F#3 D4']), clen=11.0,
                       scale=[nm(s) for s in 'D4 E4 F#4 A4 B4 D5 E5 F#5'.split()], bell_rate=.0, glassy=.5, tex='qin', final='D2 A2 F#3 B3 E4'),
}
sp = SPEC[film]
music = Bus(); sfx = Bus()

def scene_range(sid): s = SC[sid]; return s['start'], s['start'] + s['dur']
# 强度曲线：每个场景一个值
INT = {'physics': dict(rain=.35, title=.6, messengers=.5, ice=.55, flash=.75, shield=.55, discovery=.7, sources=.8, window=.9, end=.6),
       'chemistry': dict(hands=.35, title=.6, mirror=.45, life=.5, catalyst=.45, nle=.6, soai=.85, trigger=.7, meaning=.9, end=.6),
       'medicine': dict(brain=.4, title=.6, spike=.5, oldtools=.45, alga=.55, channel=.65, switch=.75, onoff=.7, map=.85, clinic=.9, end=.6),
       'literature': dict(fragment=.35, title=.55, citation=.45, eros=.5, red=.65, brackets=.5, nox=.45, forms=.6, close=.8, end=.55)}[film]
def intensity(t):
    for s in TL['scenes']:
        if s['start'] <= t < s['start'] + s['dur']: return INT.get(s['id'], .5)
    return .5

end0 = SC['end']['start']
# 1. 和弦铺底
t = 0.0; k = 0
use2_from = SC['soai']['start'] if film == 'chemistry' else 1e9
while t < end0:
    chs = sp['chords2'] if (film == 'chemistry' and t >= use2_from) else sp['chords']
    ch = chs[k % len(chs)]; d = sp['clen'] + 3.0
    I = intensity(t + 2)
    music.add(pad(ch, d, bright=.35 + .45 * I), t, gain=.55 + .35 * I)
    music.add(sub(ch[0] + (12 if ch[0] < 36 else 0), d), t, gain=.5)
    t += sp['clen']; k += 1
fin = [nm(s) for s in sp['final'].split()]
music.add(pad(fin, 12, bright=.6, att=1.5, rel=7), end0 - .5, gain=.9)
music.add(sub(fin[0] + 12, 11, att=1, rel=6), end0 - .5, gain=.5)
music.add(bell(fin[-1] + 12, 7, sp['glassy']), end0 + .2, gain=.5)

# 2. 稀疏旋律（钟、拨弦）
rng = np.random.default_rng(42)
if sp['bell_rate'] > 0:
    t = 2.0
    while t < end0 - 1:
        I = intensity(t)
        if rng.random() < sp['bell_rate'] * (.5 + I):
            m = int(rng.choice(sp['scale'])); music.add(bell(m, 5, sp['glassy']), t, gain=.22 + .2 * I, pan=float(rng.uniform(-.6, .6)))
        t += float(rng.uniform(1.2, 2.6))

# 3. 质感层
if sp['tex'] == 'wind':
    w = band_noise(TOTAL, 300, 2400, 21) * .05
    lfo = .55 + .45 * np.sin(2 * np.pi * np.arange(len(w)) / SR * .045 + 1.3)
    music.add(np.stack([w * lfo, np.roll(w, 2400) * lfo[::-1]], 1), 0, gain=1)
    a, b = scene_range('ice'); music.add(shimmer(b - a, sp['scale'], 3, 8), a, gain=.6)
elif sp['tex'] == 'arp':
    a, b = scene_range('soai'); c, d = scene_range('meaning'); bpm = 84; step = 60 / bpm / 2
    t = a; i = 0
    while t < d - 1:
        chs = sp['chords2']; ch = chs[int((t - 0) // sp['clen']) % 4]
        tones = sorted(set([m + 24 for m in ch[1:]] + [m + 36 for m in ch[2:4]]))
        pat = tones + tones[-2:0:-1]; m = pat[i % len(pat)]
        grow = min(1, (t - a) / (b - a)) if t < b else 1
        music.add(pluck(m, 1.6, .5), t, gain=.12 + .2 * grow, pan=.5 * np.sin(i * .7))
        t += step; i += 1
    a, b = scene_range('mirror'); music.add(shimmer(b - a, sp['scale'], 2, 3), a, gain=.5)
elif sp['tex'] == 'pulse':
    for sid in ['spike', 'switch', 'onoff']:
        a, b = scene_range(sid); hb = heartbeat(b - a, 60 if sid == 'spike' else 72); hb *= ramp_env(len(hb), 1.0, 1.5); music.add(hb, a, gain=.55)
    a, b = scene_range('alga'); music.add(shimmer(b - a, sp['scale'], 3, 5), a, gain=.5)
elif sp['tex'] == 'qin':
    t = 1.5
    while t < end0 - 1:
        I = intensity(t)
        if rng.random() < .55 * (.4 + I):
            m = int(rng.choice(sp['scale'])); sl = float(rng.choice([0, 0, .03, -.02]))
            music.add(pluck(m, 4.5, .45, sl), t, gain=.3 + .2 * I, pan=float(rng.uniform(-.5, .5)))
            if rng.random() < .3: music.add(pluck(m + 12, 3.5, .3), t + .02, gain=.1)
        t += float(rng.uniform(1.4, 3.2))
    for sid in ['title', 'nox', 'close']:
        a, b = scene_range(sid); music.add(bowl(nm('D3'), 9), a + .2, gain=.45)
    for sid in ['red', 'close']:
        a, b = scene_range(sid); cr = crackle(b - a); cr *= ramp_env(len(cr), 1.5, 2.0); sfx.add(cr, a, gain=.7)

# 4. 转场音效
for i, s in enumerate(TL['scenes']):
    if i == 0: continue
    st = s['start']
    if s['id'] == 'title':
        sfx.add(riser(2.6), st - 2.6, gain=.55); sfx.add(boom(3.5), st, gain=.75); sfx.add(bell(sp['scale'][0], 6, sp['glassy']), st + .05, gain=.35)
    elif s['id'] == 'end':
        sfx.add(whoosh(2.4, False, 30 + i), st - 1.3, gain=.28)
    else:
        sfx.add(whoosh(1.7, True, 30 + i), st - 1.0, gain=.22 + .1 * intensity(st))

mus = reverb(music.x, rt=3.4 if film != 'literature' else 4.0, wet=.38)
sfxr = reverb(sfx.x, rt=2.0, wet=.25)
bus = mus + sfxr
# 均衡：给人声让出 100–300 Hz，轻提高频空气感，切掉次声
def filt(x, sos): return np.stack([sg.sosfilt(sos, x[:, c]) for c in range(2)], 1).astype(np.float32)
bus = filt(bus, sg.butter(2, 32, 'highpass', fs=SR, output='sos'))
bus -= .42 * filt(bus, sg.butter(2, [95, 320], 'bandpass', fs=SR, output='sos'))
bus += .3 * filt(bus, sg.butter(2, 3200, 'highpass', fs=SR, output='sos'))
# 片尾整体淡出
fade = np.ones(N, np.float32); fs_ = int((TOTAL - 2.0) * SR); fe = int(TOTAL * SR)
fade[fs_:fe] = np.linspace(1, 0, fe - fs_) ** 1.5; fade[fe:] = 0
bus *= fade[:, None]
# 片头淡入
fi = int(1.2 * SR); bus[:fi] *= np.linspace(0, 1, fi)[:, None]

# 5. 解说闪避（侧链压缩）
nar, sr0 = sf.read(f'{ROOT}/build/{film}/narration.wav', dtype='float32')
nar = np.pad(nar, (0, max(0, N - len(nar))))[:N]
env = np.abs(nar); sos = sg.butter(1, 3.0, 'lowpass', fs=SR, output='sos'); env = sg.sosfilt(sos, env)
env = sg.sosfilt(sos, env[::-1])[::-1]
duck = 1 - .5 * np.clip(env / (np.percentile(env[env > 1e-4], 60) + 1e-9), 0, 1)
bus *= duck[:, None]

peak = np.abs(bus).max() + 1e-9
bus = bus / peak * .9
sf.write(f'{ROOT}/build/{film}/music.wav', bus[:int(TOTAL * SR)], SR)
# 粗混：解说为主，配乐约低 13 dB（最终响度由 ffmpeg loudnorm 统一）
mix = bus * .32 + np.stack([nar, nar], 1) * .92
mix = mix[:int(TOTAL * SR)]
mix /= max(1.0, np.abs(mix).max() / .97)
sf.write(f'{ROOT}/build/{film}/mix.wav', mix, SR)
print(f'{film}: music+mix written ({TOTAL:.1f}s)')
