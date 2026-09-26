#!/usr/bin/env python3
"""Render deterministic, original spell cues using only Python's standard library.

No sampled library material or external sound pack is used.  Each timbre has
separate wind-up and contact takes so game timing remains authoritative.
"""

from __future__ import annotations

import hashlib
import math
import random
import struct
import wave
from pathlib import Path


RATE = 22_050
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "UnityBattleSource/Assets/Resources/Audio/Spell"
PREVIEW = ROOT / "output/spell-audio-20260924"

# Profile, tonal centre, modulation, texture.  The game routes individual
# spells to these semantic materials, not to one shared generic explosion.
PROFILES = {
    "paper": (620, 0.18, "paper"),
    "sidestep": (780, 0.24, "air"),
    "mask": (510, 0.34, "ghost"),
    "identity": (660, 0.32, "mirror"),
    "mirror": (940, 0.36, "mirror"),
    "seal": (740, 0.30, "gold"),
    "chase": (820, 0.34, "air"),
    "climax": (520, 0.63, "gold"),
    "reversal": (580, 0.35, "mirror"),
    "ward": (560, 0.31, "heal"),
    "declaration": (480, 0.61, "bell"),
    "ghost": (370, 0.43, "ghost"),
    "fire": (320, 0.45, "fire"),
    "magma": (220, 0.55, "fire"),
    "poison": (300, 0.46, "poison"),
    "water": (440, 0.45, "water"),
    "metal": (540, 0.42, "metal"),
    "machine": (690, 0.38, "machine"),
    "silk": (730, 0.39, "silk"),
    "bell": (590, 0.45, "bell"),
    "bone": (420, 0.41, "bone"),
    "heal": (660, 0.48, "heal"),
    "beast": (280, 0.47, "beast"),
    "crystal": (910, 0.39, "crystal"),
    "stone": (240, 0.49, "stone"),
    "clock": (620, 0.47, "clock"),
    "mind": (480, 0.46, "mind"),
    "ink": (590, 0.39, "ink"),
    "frog": (390, 0.39, "frog"),
}


def render(profile: str, phase: str) -> list[float]:
    base, body, material = PROFILES[profile]
    duration = body * (0.82 if phase == "cast" else 1.22)
    if profile == "paper":
        duration = 0.16 if phase == "cast" else 0.26
    if profile == "climax" and phase == "impact":
        duration = 0.79
    count = round(RATE * duration)
    random_seed = int.from_bytes(hashlib.sha256(f"{profile}:{phase}".encode()).digest()[:8], "little")
    noise = random.Random(random_seed)
    fast = slow = 0.0
    phase1 = phase2 = phase3 = 0.0
    out: list[float] = []

    for i in range(count):
        t = i / RATE
        u = t / duration
        raw = noise.uniform(-1, 1)
        fast += (raw - fast) * 0.40
        slow += (raw - slow) * 0.025
        airy = fast - slow
        attack = min(1.0, t / 0.004)
        tail = (1 - u) ** (1.5 if phase == "cast" else 2.7)
        env = attack * tail
        sweep = math.sin(math.pi * u) ** 0.7 if phase == "cast" else math.exp(-u * 3.0)
        glide = (0.72 + 0.5 * u) if phase == "cast" else (1.45 - 0.8 * u)
        wobble = 1 + 0.009 * math.sin(2 * math.pi * 12.0 * t)
        phase1 += 2 * math.pi * base * glide * wobble / RATE
        phase2 += 2 * math.pi * base * 1.51 * glide / RATE
        phase3 += 2 * math.pi * (base * 0.48) * (1.2 - 0.35 * u) / RATE
        tone = math.sin(phase1) + 0.22 * math.sin(phase2)
        thump = math.sin(phase3) * math.exp(-t * (15 if phase == "impact" else 8))
        click = raw * math.exp(-t * 75) if phase == "impact" else 0.0
        sample = 0.0

        if material == "paper":
            flutter = 0.58 + 0.42 * math.sin(2 * math.pi * 31 * t) ** 2
            sample = airy * flutter * (0.85 if phase == "cast" else 0.45) + tone * 0.18 + click * 0.44
        elif material == "air":
            sample = airy * (0.75 * sweep + 0.25) + tone * 0.23 + click * 0.19
        elif material == "ghost":
            sample = airy * 0.38 + (math.sin(phase1) - 0.33 * math.sin(phase2)) * (0.62 + 0.25 * math.sin(2 * math.pi * 9 * t)) + thump * 0.19
        elif material == "mirror":
            chime = math.sin(phase1 * 2.15) + 0.38 * math.sin(phase2 * 2.75)
            sample = chime * 0.50 + airy * 0.28 + click * 0.20
        elif material == "gold":
            arpeggio = math.sin(phase1 * 2.02) * (0.50 + 0.50 * math.sin(2 * math.pi * 17 * t) ** 2)
            sample = tone * 0.48 + arpeggio * 0.38 + airy * 0.22 + thump * (0.31 if phase == "impact" else 0.04)
        elif material == "fire":
            crackle = raw * (1 if noise.random() > 0.993 else 0)
            sample = airy * 0.95 + raw * 0.16 + crackle * 0.72 + thump * (0.67 if phase == "impact" else 0.15)
        elif material == "poison":
            bubble = math.sin(phase1 * (0.45 + 0.2 * math.sin(2 * math.pi * 6 * t))) * max(0, math.sin(2 * math.pi * 8.5 * t)) ** 5
            sample = airy * 0.33 + bubble * 0.78 + thump * 0.15
        elif material == "water":
            droplets = math.sin(phase1 * 2.71) * max(0, math.sin(2 * math.pi * 15 * t)) ** 7
            sample = airy * 0.71 + droplets * 0.37 + thump * 0.25
        elif material == "metal":
            clang = math.sin(phase1 * 2.32) + 0.47 * math.sin(phase2 * 2.91)
            sample = clang * 0.56 + thump * 0.57 + click * 0.56 + airy * 0.16
        elif material == "machine":
            teeth = max(0, math.sin(2 * math.pi * 24 * t)) ** 7
            sample = tone * 0.32 + airy * teeth * 0.65 + click * 0.29 + thump * 0.23
        elif material == "silk":
            taut = math.sin(phase1 * 1.85) * math.exp(-t * (13 if phase == "impact" else 4))
            sample = airy * 0.54 + taut * 0.52 + click * 0.37
        elif material in {"bell", "clock"}:
            pulse = sum(math.exp(-max(0, t - onset) * 35) if t >= onset else 0 for onset in ([0, 0.085, 0.17] if material == "bell" else [0, 0.13]))
            bell = math.sin(phase1) + 0.44 * math.sin(phase1 * 2.71) + 0.18 * math.sin(phase1 * 4.04)
            sample = bell * pulse * 0.47 + airy * 0.15 + thump * (0.38 if phase == "impact" else 0.02)
        elif material == "bone":
            scrape = airy * (0.30 + 0.7 * max(0, math.sin(2 * math.pi * 27 * t)))
            sample = scrape * 0.64 + click * 0.51 + thump * 0.39
        elif material == "heal":
            sample = tone * 0.40 + math.sin(phase1 * 1.51) * 0.24 + airy * 0.11
        elif material == "beast":
            growl = math.sin(phase1 * 0.54 + 0.8 * math.sin(phase3))
            sample = growl * 0.57 + airy * 0.46 + thump * 0.54
        elif material == "crystal":
            sample = (math.sin(phase1 * 2.02) + 0.38 * math.sin(phase1 * 3.31)) * 0.45 + airy * 0.25 + click * 0.43
        elif material == "stone":
            rubble = raw * max(0, math.sin(2 * math.pi * 29 * t)) ** 4
            sample = rubble * 0.40 + airy * 0.39 + thump * 0.82
        elif material == "mind":
            warped = math.sin(phase1 + 1.4 * math.sin(phase3))
            sample = warped * 0.54 + airy * 0.28 + math.sin(phase2 * 1.73) * 0.17
        elif material == "ink":
            blot = math.sin(phase1 * 0.67) * max(0, math.sin(2 * math.pi * 13 * t)) ** 2
            sample = blot * 0.49 + airy * 0.38 + click * 0.24
        elif material == "frog":
            croak = math.sin(phase1 * (0.74 - 0.26 * u) + 0.58 * math.sin(phase3))
            sample = croak * 0.66 + airy * 0.34 + click * 0.21

        if phase == "cast":
            sample *= env * (0.33 + 0.67 * sweep)
        else:
            sample *= env
        out.append(sample)

    # Quiet, short echoes add space without smearing the next action.
    echo = round(RATE * (0.045 if material in {"paper", "silk", "machine"} else 0.085))
    wet = 0.11 if material in {"paper", "machine", "stone", "bone"} else 0.19
    for i in range(echo, count):
        out[i] += out[i - echo] * wet
    peak = max(max(abs(x) for x in out), 0.001)
    gain = 0.67 if profile in {"climax", "declaration", "magma"} else 0.58
    return [max(-1, min(1, x * gain / peak)) for x in out]


def write_wave(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", round(sample * 32767)) for sample in samples))


def main() -> None:
    preview: list[float] = []
    for name in PROFILES:
        for phase in ("cast", "impact"):
            samples = render(name, phase)
            write_wave(DEST / f"{name}_{phase}.wav", samples)
            preview.extend(samples)
            preview.extend([0.0] * round(RATE * 0.14))
    write_wave(PREVIEW / "spell-sfx-audition.wav", preview)
    print(f"Rendered {len(PROFILES) * 2} cues and audition into {DEST}")


if __name__ == "__main__":
    main()
