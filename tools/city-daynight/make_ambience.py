"""Procedural ambience for the city hub (all original, synthesised here).

usage: make_ambience.py <out_dir> [name ...]   (only the named sounds)

Loops are generated as circular signals (filtering and envelopes done in the
frequency domain over the exact loop length), so they repeat without a seam.
Each loop comes in two takes of different length (<name>_a, <name>_b):
  sea            harbour water lapping against quays and hulls
  wind_soft      light breeze with slow gusts
  wind_strong    storm or blizzard wind with gust whistle
  rain_light     drizzle: fine hiss and sparse drops
  rain_heavy     downpour: roar, rumble and dense splashes
  crickets       summer / autumn night crickets
One-shots:
  thunder_near_1..3, thunder_far_1..3, gull_1..6, songbird_1..6, owl_1..2, bell,
  splash_1..3 (wave on the quay), gust_1..3, creak_1..3 (timber and rope),
  shipbell_1..2 (a ship's bell across the water)
Writes mono 22.05 kHz ALAC .caf files (lossless, so loops stay seamless)
plus the same as .wav under <out_dir>/wav for inspection.
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 22050
rng = np.random.default_rng(20260927)


# ---------------------------------------------------------------- helpers

def freqs(n):
    return np.fft.rfftfreq(n, 1 / SR)


def shape(x, gain_fn):
    """Circular filter: multiply the spectrum by gain_fn(f)."""
    X = np.fft.rfft(x)
    return np.fft.irfft(X * gain_fn(freqs(len(x))), len(x))


def band(lo, hi, order=2):
    def g(f):
        f = np.maximum(f, 1e-3)
        hp = 1 / np.sqrt(1 + (lo / f) ** (2 * order)) if lo > 0 else 1
        lp = 1 / np.sqrt(1 + (f / hi) ** (2 * order)) if hi else 1
        return hp * lp
    return g


def resonance(fc, q):
    def g(f):
        return 1 / np.sqrt(1 + (q * (f / fc - fc / np.maximum(f, 1e-3))) ** 2)
    return g


def pink(n):
    return shape(rng.standard_normal(n), lambda f: 1 / np.sqrt(np.maximum(f, 20)))


def brown(n):
    return shape(rng.standard_normal(n), lambda f: 1 / np.maximum(f, 20))


def envelope(n, cutoff_hz, lo=0.0, hi=1.0):
    """Smooth random circular envelope."""
    e = shape(rng.standard_normal(n), lambda f: np.exp(-(f / cutoff_hz) ** 2))
    e = (e - e.min()) / (e.max() - e.min() + 1e-12)
    return lo + (hi - lo) * e


def norm_rms(x, db):
    return x * (10 ** (db / 20) / (np.sqrt(np.mean(x ** 2)) + 1e-12))


def limit(x, ceiling_db=-1.0):
    """Soft-knee peak limiter: transparent below the knee, never above the ceiling."""
    c = 10 ** (ceiling_db / 20)
    knee = 0.7 * c
    a = np.abs(x)
    over = a > knee
    y = x.copy()
    y[over] = np.sign(x[over]) * (knee + (c - knee) * np.tanh((a[over] - knee) / (c - knee)))
    return y


def norm_peak(x, db):
    return x * (10 ** (db / 20) / (np.max(np.abs(x)) + 1e-12))


def add_circular(buf, event, at):
    n = len(buf)
    idx = (np.arange(len(event)) + at) % n
    np.add.at(buf, idx, event)


def reverb(x, seconds, wet, tail_lp=4000):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t / (seconds / 5))
    ir = shape(ir, band(0, tail_lp))
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
    y = np.convolve(x, ir)[: len(x) + n]
    out = np.zeros(len(y))
    out[: len(x)] += x
    return out + wet * y


def fade(x, fin=0.01, fout=0.2):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    w = np.ones(n)
    if a: w[:a] = np.linspace(0, 1, a)
    if b: w[-b:] = np.linspace(1, 0, b)
    return x * w


def tone(freq_curve, amps=(1.0,), noise=0.0):
    """Harmonic tone following an instantaneous frequency curve."""
    phase = 2 * np.pi * np.cumsum(freq_curve) / SR
    y = sum(a * np.sin((k + 1) * phase) for k, a in enumerate(amps))
    if noise:
        y = y + noise * rng.standard_normal(len(y))
    return y


# ---------------------------------------------------------------- loops

def sea(seconds=32):
    n = int(seconds * SR)
    body = shape(brown(n) + 0.3 * pink(n), band(60, 900))
    swell = envelope(n, 0.18, 0.35, 1.0)
    water = body * swell
    laps = np.zeros(n)
    t = 0.0
    while t < seconds:
        m = int((0.18 + 0.5 * rng.random()) * SR)
        tt = np.arange(m) / SR
        burst = rng.standard_normal(m) * np.minimum(1, tt / 0.06) * np.exp(-tt / (0.12 + 0.2 * rng.random()))
        burst = shape(burst, band(250 + 300 * rng.random(), 2200 + 1500 * rng.random()))
        thump = np.sin(2 * np.pi * (90 + 60 * rng.random()) * tt) * np.exp(-tt / 0.09) * 0.6
        add_circular(laps, (burst + thump) * (0.4 + 0.8 * rng.random()), int(t * SR))
        t += 1.2 + 2.8 * rng.random()
    return norm_rms(norm_rms(water, -20) + norm_rms(laps, -24), -20)


def wind(seconds, strong):
    n = int(seconds * SR)
    gusts = envelope(n, 0.10 if not strong else 0.16, 0.25 if not strong else 0.45, 1.0)
    base = shape(pink(n), band(120, 1800 if not strong else 2600))
    out = base * gusts
    centres = [380, 620, 900] if not strong else [520, 820, 1250, 1700]
    for c in centres:
        whistle = shape(rng.standard_normal(n), resonance(c * (0.9 + 0.2 * rng.random()), 14 if strong else 9))
        out += norm_rms(whistle, -30 if not strong else -24) / 10 ** (-20 / 20) * 0.1 * envelope(n, 0.07, 0, 1) * gusts
    if strong:
        roar = shape(brown(n), band(30, 260)) * envelope(n, 0.2, 0.4, 1.0)
        out = norm_rms(out, -20) + norm_rms(roar, -22)
    return norm_rms(out, -21 if not strong else -17)


def drops(n, rate, pitch_lo, pitch_hi, length_ms):
    out = np.zeros(n)
    count = int(rate * n / SR)
    for _ in range(count):
        m = int((length_ms * (0.5 + rng.random())) / 1000 * SR)
        tt = np.arange(m) / SR
        f = pitch_lo + (pitch_hi - pitch_lo) * rng.random()
        d = (np.sin(2 * np.pi * f * tt * (1 - 0.3 * tt / tt[-1])) * 0.6 + rng.standard_normal(m) * 0.5) * np.exp(-tt / (length_ms / 4000))
        add_circular(out, d * (0.2 + rng.random() ** 2), rng.integers(0, n))
    return out


def rain(seconds, heavy):
    n = int(seconds * SR)
    if not heavy:
        hiss = shape(rng.standard_normal(n), band(1500, 8500)) * envelope(n, 0.25, 0.6, 1.0)
        patter = drops(n, 45, 1800, 5500, 12)
        return norm_rms(norm_rms(hiss, -30) + norm_rms(patter, -27), -25)
    roar = shape(rng.standard_normal(n), band(300, 9000)) * envelope(n, 0.3, 0.7, 1.0)
    rumble = shape(brown(n), band(50, 400)) * envelope(n, 0.15, 0.6, 1.0)
    splash = shape(drops(n, 260, 900, 4200, 18), band(600, 7000))
    return norm_rms(norm_rms(roar, -20) + norm_rms(rumble, -24) + norm_rms(splash, -23), -17)


def crickets(seconds=24):
    n = int(seconds * SR)
    out = np.zeros(n)
    for voice in range(4):
        f = 4000 + 900 * rng.random()
        period = 0.42 + 0.35 * rng.random()
        amp = 0.35 + 0.65 * rng.random()
        pulses = 2 + int(rng.random() * 3)
        t = rng.random() * period
        pulse_len = int(0.013 * SR)
        tt = np.arange(pulse_len) / SR
        pulse = np.sin(2 * np.pi * f * tt) * np.hanning(pulse_len)
        while t < seconds:
            for k in range(pulses):
                add_circular(out, pulse * amp * (0.8 + 0.4 * rng.random()), int((t + k * 0.021) * SR))
            t += period * (0.92 + 0.16 * rng.random())
    out *= envelope(n, 0.05, 0.6, 1.0)
    return norm_rms(shape(out, band(2500, 7000)), -28)


# ---------------------------------------------------------------- one-shots

def thunder(near):
    """A thunderclap that still carries on a phone speaker.

    Near: a sharp split-second crack and a tearing rip, then a rolling rumble
    with crackle in it. Far: no crack, a slow rolling rumble. The rumble is
    driven into soft saturation so its harmonics (100–1500 Hz) carry the
    weight that small speakers cannot play as bass.
    """
    seconds = 10 if near else 9
    n = int(seconds * SR)
    t = np.arange(n) / SR
    # Rolling: a handful of swells of different width, the first the loudest.
    rolls = np.zeros(n)
    starts = np.sort((0.15 if near else 0.7) + (5.0 if near else 5.5) * rng.random(7 if near else 5))
    for k, c in enumerate(starts):
        w = 0.2 + 0.7 * rng.random()
        rolls += (1.0 if k == 0 else 0.35 + 0.55 * rng.random()) * np.exp(-((t - c) / w) ** 2)
    onset = np.minimum(1, t / (0.06 if near else 0.7))
    decay = np.exp(-t / (2.8 if near else 2.4))
    body = shape(brown(n) + 0.15 * pink(n), band(35, 650 if near else 420))
    body = body / (np.max(np.abs(body)) + 1e-12)
    drive = np.tanh(3.2 * body) * (0.25 + rolls) * onset * decay
    rumble = 0.7 * shape(drive, band(45, 1600 if near else 900)) + 0.5 * shape(drive, band(110, 700))
    # Crackle riding on the rumble: sparse snaps, denser at the start.
    crackle = np.zeros(n)
    count = 140 if near else 50
    for _ in range(count):
        at = int(min(n - 400, abs(rng.normal(0.4 if near else 1.5, 1.6)) * SR))
        m = int((0.004 + 0.02 * rng.random()) * SR)
        snap = rng.standard_normal(m) * np.exp(-np.arange(m) / (m / 4))
        crackle[at:at + m] += snap * (0.3 + 0.7 * rng.random())
    crackle = shape(crackle, band(500, 3500 if near else 1800)) * decay * (0.4 + rolls)
    x = norm_rms(rumble, -16) + norm_rms(crackle, -26 if near else -34)
    if near:
        # The crack: a few very short bright bursts, then a tearing rip.
        m = int(0.9 * SR)
        tc = np.arange(m) / SR
        crack = np.zeros(m)
        for k in range(5):
            at = int((0.0 if k == 0 else 0.02 + 0.12 * rng.random()) * SR)
            burst = rng.standard_normal(m - at) * np.exp(-np.arange(m - at) / SR / (0.012 + 0.03 * rng.random()))
            crack[at:] += burst * (1.0 if k == 0 else 0.4 + 0.5 * rng.random())
        crack = shape(crack, band(250, 9000))
        rip = shape(rng.standard_normal(m), band(350, 3200)) * np.exp(-tc / 0.28)
        rip *= 0.55 + 0.45 * np.sin(2 * np.pi * (35 + 25 * tc) * tc) ** 2
        x[:m] += norm_peak(crack, -1) + norm_peak(rip, -5)
    x = reverb(x, 3.0, 0.35, 2500)
    # Loudness where a phone can play it: the audible band (>250 Hz) of the
    # first three seconds sets the level; the limiter in write() takes the
    # peaks, which only roughens the crack.
    f = np.fft.rfftfreq(len(x), 1 / SR)
    audible = np.fft.irfft(np.fft.rfft(x) * (f >= 250), len(x))[: 3 * SR]
    gain = 10 ** ((-11 if near else -16) / 20) / (np.sqrt(np.mean(audible ** 2)) + 1e-12)
    return fade(x * gain, 0.001, 1.0)


def gull(variant):
    notes = []
    count = [4, 6, 3, 5, 4, 3][variant]
    base = [1.0, 0.92, 1.1, 0.97, 1.05, 0.88][variant]
    for k in range(count):
        d = 0.22 + 0.16 * rng.random() if k else 0.42
        m = int(d * SR)
        u = np.linspace(0, 1, m)
        fa, fb, fc = 620 * base, 930 * base, 560 * base
        fa, fb, fc = [v * (1 - 0.04 * k) * (0.95 + 0.1 * rng.random()) for v in (fa, fb, fc)]
        rise = np.clip(u / 0.3, 0, 1) ** 0.7
        fall = np.clip((u - 0.3) / 0.7, 0, 1) ** 1.4
        curve = np.where(u < 0.3, fa + (fb - fa) * rise, fb + (fc - fb) * fall)
        y = tone(curve, amps=(1.0, 0.75, 0.55, 0.45, 0.30, 0.20, 0.12, 0.07))
        y *= 1 + 0.35 * np.sin(2 * np.pi * 85 * np.arange(m) / SR)          # rasp
        y = shape(y, lambda f: 0.35 + resonance(1700, 2.5)(f) + 0.7 * resonance(3100, 3)(f))
        y += 0.12 * np.max(np.abs(y)) * shape(rng.standard_normal(m), band(1200, 4500))
        env = np.minimum(1, u * d / 0.02) * np.minimum(1, (1 - u) * d / 0.06)
        notes.append(y * env)
        notes.append(np.zeros(int((0.05 + 0.09 * rng.random()) * SR)))
    x = np.concatenate(notes)
    x = shape(x, band(400, 5500))
    return fade(norm_peak(reverb(x, 1.0, 0.18, 3500), -3), 0.001, 0.4)


def songbird(variant):
    parts = []
    syllables = 7 + int(rng.random() * 7)
    for k in range(syllables):
        kind = rng.integers(0, 4)
        if kind == 0:   # up-sweep
            d = 0.05 + 0.03 * rng.random(); m = int(d * SR)
            curve = np.linspace(2600, 5200, m) * (0.9 + 0.2 * rng.random())
        elif kind == 1:  # down-sweep
            d = 0.04 + 0.04 * rng.random(); m = int(d * SR)
            curve = np.linspace(5400, 2900, m) * (0.9 + 0.2 * rng.random())
        elif kind == 2:  # trill
            d = 0.15 + 0.15 * rng.random(); m = int(d * SR)
            tt = np.arange(m) / SR
            curve = (3800 + 700 * np.sin(2 * np.pi * (26 + 10 * rng.random()) * tt)) * (0.9 + 0.2 * rng.random())
        else:            # whistle with vibrato
            d = 0.10 + 0.12 * rng.random(); m = int(d * SR)
            tt = np.arange(m) / SR
            curve = (3100 + 120 * np.sin(2 * np.pi * 9 * tt)) * (0.9 + 0.25 * rng.random())
        y = tone(curve, amps=(1.0, 0.12)) * np.hanning(m) ** 0.6
        parts.append(y * (0.6 + 0.4 * rng.random()))
        parts.append(np.zeros(int((0.02 + 0.09 * rng.random()) * SR)))
    x = np.concatenate(parts)
    return fade(norm_peak(reverb(x, 0.8, 0.12, 6000), -6), 0.001, 0.3)


def owl(variant=0):
    parts = []
    calls = [[(0.55, 470, 0.9), (0.14, 455, 0.12), (0.12, 450, 0.10), (0.9, 440, 0)],
             [(0.45, 515, 0.35), (0.62, 500, 0)]][variant]
    for d, f0, gap in calls:
        m = int(d * SR)
        u = np.linspace(0, 1, m)
        curve = f0 * (1.03 - 0.06 * u)
        y = tone(curve, amps=(1.0, 0.18, 0.05), noise=0.08)
        y = shape(y, band(250, 1500))
        parts.append(y * np.sin(np.pi * u) ** 0.8)
        parts.append(np.zeros(int(gap * SR)))
    x = np.concatenate(parts)
    return fade(norm_peak(reverb(x, 1.6, 0.3, 2000), -8), 0.001, 0.8)


def splash():
    """A wave slapping the quay: a low thump, the wash, a few drips."""
    d = 1.6 + 0.8 * rng.random()
    n = int(d * SR)
    t = np.arange(n) / SR
    thump = shape(rng.standard_normal(n), band(60, 300)) * np.exp(-t / 0.12)
    wash = shape(rng.standard_normal(n), band(400, 5000)) * np.minimum(1, t / 0.05) * np.exp(-t / (0.35 + 0.2 * rng.random()))
    drips = drops(n, 25, 1200, 4000, 15) * np.exp(-t / 0.6)
    x = norm_rms(thump, -22) + norm_rms(wash, -20) + norm_rms(drips, -28)
    return fade(norm_peak(reverb(x, 0.8, 0.15, 3000), -4), 0.002, 0.4)


def gust():
    """A single gust passing: a rise and fall of wind with a gliding whistle."""
    d = 3.5 + 2.5 * rng.random()
    n = int(d * SR)
    t = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    base = shape(pink(n), band(150, 2500))
    c0 = 400 + 300 * rng.random()
    c1 = c0 * (1.6 + 0.4 * rng.random())
    sweep = np.clip(t / d, 0, 1)
    whistle = norm_rms(shape(rng.standard_normal(n), resonance(c0, 6)), -30) * (1 - sweep) \
        + norm_rms(shape(rng.standard_normal(n), resonance(c1, 8)), -30) * sweep
    x = (norm_rms(base, -20) + 0.6 * whistle) * env
    return fade(norm_peak(x, -5), 0.01, 0.5)


def creak():
    """Ship's timber or a mooring rope working: stick-slip clicks at a
    gliding rate through a wooden body."""
    d = 0.6 + 0.8 * rng.random()
    n = int(d * SR)
    t = np.arange(n) / SR
    rate = 25 + 45 * (t / d) if rng.random() < 0.5 else 70 - 40 * (t / d)
    phase = np.cumsum(rate) / SR
    clicks = np.zeros(n)
    idx = np.nonzero(np.diff(np.floor(phase)) > 0)[0]
    clicks[idx] = 0.6 + 0.4 * rng.random(len(idx))
    body = shape(clicks, resonance(420 + 300 * rng.random(), 7)) + 0.6 * shape(clicks, resonance(1100 + 500 * rng.random(), 9))
    x = body * np.sin(np.pi * t / d) ** 0.6
    return fade(norm_peak(reverb(x, 0.5, 0.2, 2500), -8), 0.005, 0.1)


def shipbell():
    """A small ship's bell rung in pairs, far across the water."""
    strikes = [0.0, 0.42] if rng.random() < 0.5 else [0.0, 0.42, 1.3, 1.72]
    d = strikes[-1] + 3.0
    n = int(d * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    nominal = 1180 * (0.95 + 0.1 * rng.random())
    for s0 in strikes:
        tt = t - s0
        on = tt >= 0
        for ratio, amp, tau in [(1.0, 1.0, 1.4), (2.0, 0.5, 0.8), (2.74, 0.35, 0.5), (3.9, 0.2, 0.3), (0.5, 0.3, 1.8)]:
            x[on] += amp * np.sin(2 * np.pi * nominal * ratio * tt[on]) * np.exp(-tt[on] / tau)
        x[on] += 0.3 * shape(rng.standard_normal(int(on.sum())), band(2000, 6000)) * np.exp(-tt[on] / 0.01)
    x = shape(x, band(300, 3500))
    return fade(norm_peak(reverb(x, 1.8, 0.35, 2500), -9), 0.001, 0.6)


def bell():
    seconds = 7
    n = int(seconds * SR)
    t = np.arange(n) / SR
    nominal = 660
    partials = [(0.5, 0.55, 6.0), (1.0, 0.45, 3.8), (1.2, 0.42, 2.8), (1.5, 0.28, 2.0), (2.0, 0.60, 1.7),
                (2.51, 0.22, 1.0), (2.67, 0.16, 0.8), (3.01, 0.14, 0.6), (4.07, 0.08, 0.35)]
    x = np.zeros(n)
    for ratio, amp, tau in partials:
        f = nominal * ratio
        beat = 1 + 0.25 * np.sin(2 * np.pi * (0.4 + rng.random()) * t)
        x += amp * np.sin(2 * np.pi * f * t + rng.random() * 6.28) * np.exp(-t / tau) * beat
    strike_n = int(0.01 * SR)
    x[:strike_n] += shape(rng.standard_normal(strike_n), band(1500, 6000)) * np.linspace(1, 0, strike_n) * 0.6
    x = shape(x, band(80, 4200))
    return fade(norm_peak(reverb(x, 2.2, 0.35, 3000), -4), 0.001, 1.0)


# ---------------------------------------------------------------- write

def write(out, name, x):
    wav_dir = os.path.join(out, "wav")
    os.makedirs(wav_dir, exist_ok=True)
    path = os.path.join(wav_dir, name + ".wav")
    x = limit(x)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    subprocess.run(["afconvert", "-f", "caff", "-d", "alac", path, os.path.join(out, name + ".caf")], check=True)
    return path


def main():
    out = sys.argv[1]
    only = set(sys.argv[2:])
    os.makedirs(out, exist_ok=True)
    # Every loop in two takes of different length, played together and
    # cross-faded slowly in the game, so the mix never repeats exactly.
    items = {
        "sea_a": sea(41), "sea_b": sea(53),
        "wind_soft_a": wind(37, False), "wind_soft_b": wind(47, False),
        "wind_strong_a": wind(39, True), "wind_strong_b": wind(49, True),
        "rain_light_a": rain(36, False), "rain_light_b": rain(46, False),
        "rain_heavy_a": rain(38, True), "rain_heavy_b": rain(50, True),
        "crickets_a": crickets(33), "crickets_b": crickets(43),
        "bell": bell(),
    }
    for k in range(1, 4):
        items[f"thunder_near_{k}"] = thunder(True)
        items[f"thunder_far_{k}"] = thunder(False)
        items[f"splash_{k}"] = splash()
        items[f"gust_{k}"] = gust()
        items[f"creak_{k}"] = creak()
    for k in range(1, 7):
        items[f"gull_{k}"] = gull(k - 1)
        items[f"songbird_{k}"] = songbird(k - 1)
    for k in range(1, 3):
        items[f"owl_{k}"] = owl(k - 1)
        items[f"shipbell_{k}"] = shipbell()
    for name, x in items.items():
        if only and name not in only:
            continue
        write(out, name, x)
        x = limit(x)
        print(f"{name:16s} {len(x) / SR:5.1f}s  rms {20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12):6.1f} dB  peak {20 * np.log10(np.max(np.abs(x)) + 1e-12):5.1f} dB")


if __name__ == "__main__":
    main()
