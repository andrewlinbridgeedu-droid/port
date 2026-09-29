"""Offline preview of the city hub ambience, mixed the way CityAmbience does it.

usage: demo_mix.py <wav_dir> <out.wav>

Six scenes of the harbour back to back, each with the loop levels and
one-shots CityAmbience would choose for that hour, season and weather.
Only for listening; the game mixes live with AVAudioEngine.
"""
import sys
import wave

import numpy as np

SR = 22050
rng = np.random.default_rng(7)
src = sys.argv[1]


def read(name):
    w = wave.open(f"{src}/{name}.wav")
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768
    return x


def pan_gains(p):
    a = (p + 1) * np.pi / 4
    return np.cos(a), np.sin(a)


# (title, seconds, loop levels, one-shots [(time, name, volume, pan)])
scenes = [
    ("Spring dawn 06:00 - clock tower, songbirds, gulls", 18,
     {"sea": 0.47, "wind_soft": 0.22},
     [(0.4 + 2.3 * i, "bell", 0.42 - 0.012 * i, -0.1) for i in range(6)]
     + [(1.5, "songbird_1", 0.42, -0.6), (4.0, "songbird_3", 0.38, 0.5), (6.2, "songbird_2", 0.45, 0.1),
        (8.5, "gull_2", 0.35, 0.6), (10.0, "songbird_1", 0.4, 0.7), (12.4, "songbird_3", 0.36, -0.4),
        (14.0, "songbird_2", 0.44, -0.7), (15.6, "gull_1", 0.4, -0.3)]),
    ("Summer noon - harbour, gulls, breeze", 14,
     {"sea": 0.55, "wind_soft": 0.3},
     [(1.0, "gull_1", 0.5, 0.4), (3.5, "gull_3", 0.42, -0.5), (6.0, "songbird_2", 0.3, 0.2),
      (8.0, "gull_2", 0.55, -0.1), (11.0, "gull_1", 0.38, 0.7)]),
    ("Summer thunderstorm - downpour, storm wind, near and far thunder", 22,
     {"sea": 0.72, "wind_soft": 0.25, "wind_strong": 0.55, "rain_heavy": 0.95},
     [(1.2, "thunder_near_1", 0.95, 0.3), (8.5, "thunder_far_1", 0.7, -0.6),
      (14.0, "thunder_near_2", 0.95, -0.2), (19.5, "thunder_far_2", 0.7, 0.5)]),
    ("Autumn drizzle", 14,
     {"sea": 0.5, "wind_soft": 0.3, "rain_light": 0.85},
     [(5.0, "gull_3", 0.22, 0.5)]),
    ("Summer night - crickets, owl", 16,
     {"sea": 0.43, "wind_soft": 0.22, "crickets": 0.8},
     [(3.0, "owl_1", 0.3, -0.4), (11.0, "owl_1", 0.26, 0.3)]),
    ("Winter night blizzard", 14,
     {"sea": 0.36, "wind_soft": 0.34, "wind_strong": 0.9},
     []),
]

XF = 2.0
total = sum(s[1] for s in scenes) + XF
out = np.zeros((int(total * SR), 2))
start = 0.0
cues = []
for title, dur, loops, shots in scenes:
    n = int((dur + XF) * SR)
    i0 = int(start * SR)
    t = np.arange(n) / SR
    # Fade in over the crossfade, hold, fade out over the next crossfade.
    fade = np.clip(t / XF, 0, 1) * np.clip((dur + XF - t) / XF, 0, 1)
    fade = np.sin(fade * np.pi / 2) ** 2
    for name, level in loops.items():
        x = read(name)
        off = rng.integers(0, len(x))
        seg = np.resize(np.roll(x, -off), n) * level * fade
        l, r = pan_gains(0.0)
        out[i0:i0 + n, 0] += seg * l * np.sqrt(2)
        out[i0:i0 + n, 1] += seg * r * np.sqrt(2)
    for at, name, vol, p in shots:
        x = read(name) * vol
        j = i0 + int((at + XF / 2) * SR)
        m = min(len(x), len(out) - j)
        l, r = pan_gains(p)
        out[j:j + m, 0] += x[:m] * l * np.sqrt(2)
        out[j:j + m, 1] += x[:m] * r * np.sqrt(2)
    cues.append((start + XF / 2, title))
    start += dur

# The default ambience volume is 0.6 of full; preview a bit louder for clarity.
out *= 0.8
peak = np.abs(out).max()
if peak > 0.95:
    out *= 0.95 / peak
w = wave.open(sys.argv[2], "wb")
w.setnchannels(2)
w.setsampwidth(2)
w.setframerate(SR)
w.writeframes((out * 32767).astype(np.int16).tobytes())
w.close()
for at, title in cues:
    print(f"{int(at // 60)}:{int(at % 60):02d}  {title}")
print(f"length {total:.0f}s, peak {20 * np.log10(np.abs(out).max()):.1f} dBFS")
