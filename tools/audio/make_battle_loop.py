#!/usr/bin/env python3
"""Create a crossfaded gameplay loop from Gemini's decoded stereo WAV.

The original generated MP3 remains separately archived for comparison.
Input WAV is produced by macOS afconvert; output WAV is then AAC encoded.
"""

from __future__ import annotations

import array
import math
import sys
import wave
from pathlib import Path


def main() -> None:
    source = Path(sys.argv[1])
    target = Path(sys.argv[2])
    with wave.open(str(source), "rb") as infile:
        channels = infile.getnchannels()
        rate = infile.getframerate()
        assert channels == 2 and infile.getsampwidth() == 2
        pcm = array.array("h")
        pcm.frombytes(infile.readframes(infile.getnframes()))

    start = 5.45  # bypass the generated lead-in
    end = 177.0   # bypass its fade-to-silence ending
    overlap = 2.73  # about 1.5 bars at the requested 132 BPM
    first = round(start * rate) * channels
    last = round(end * rate) * channels
    blend_count = round(overlap * rate)
    selection = pcm[first:last]
    body = array.array("h", selection[blend_count * channels:-blend_count * channels])
    for frame in range(blend_count):
        phase = frame / max(1, blend_count - 1)
        a = math.cos(phase * math.pi / 2)
        b = math.sin(phase * math.pi / 2)
        for channel in range(channels):
            tail = selection[(len(selection) // channels - blend_count + frame) * channels + channel]
            head = selection[frame * channels + channel]
            mixed = round((tail * a + head * b) / math.sqrt(a * a + b * b))
            body.append(max(-32768, min(32767, mixed)))
    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as out:
        out.setnchannels(channels)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(body.tobytes())
    print(f"loop_seconds={len(body) / channels / rate:.3f}")


if __name__ == "__main__":
    main()
