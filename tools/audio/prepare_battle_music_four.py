#!/usr/bin/env python3
"""Inspect and prepare the four user-supplied battle themes for iOS looping.

No generated or stock music is mixed into these files. Original MP3s are copied
unchanged to the review directory; only their gameplay copies are crossfaded
and AAC encoded. macOS afconvert supplies the codec, Python handles PCM edits.
"""

from __future__ import annotations

import argparse
import array
import json
import math
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DOWNLOADS = Path("/Users/andrewlin/Downloads")
REVIEW = ROOT / "output/battle-music-four-20260924"
RUNTIME = ROOT / "mistport-ios/Mistport/Audio"

# The end cut is before each generated song's fade to silence. Crossfading its
# tail into its own opening creates a continuous gameplay loop, not a remix.
TRACKS = {
    "petals": ("Petals_on_the_River.mp3", "BattlePetalsRiver.m4a", 5.0, 111.5, 2.8),
    "gears": ("Gears_Against_the_Fog.mp3", "BattleGearsFog.m4a", 5.0, 176.0, 2.8),
    "harbor": ("The_Harbor’s_Iron_Toll.mp3", "BattleHarborIronToll.m4a", 5.0, 175.0, 2.8),
    "brass": ("March_of_the_Brass_Tide.mp3", "BattleBrassTide.m4a", 7.0, 172.5, 2.8),
}


def decode(source: Path, wav_path: Path) -> tuple[array.array, int]:
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", str(source), str(wav_path)], check=True)
    with wave.open(str(wav_path), "rb") as audio:
        if audio.getnchannels() != 2 or audio.getsampwidth() != 2:
            raise ValueError(f"Expected 16-bit stereo PCM: {source}")
        samples = array.array("h")
        samples.frombytes(audio.readframes(audio.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
        return samples, audio.getframerate()


def rms(samples: array.array, rate: int, start: float, seconds: float) -> float:
    start_frame = max(0, round(start * rate))
    end_frame = min(len(samples) // 2, round((start + seconds) * rate))
    # Sparse sampling keeps the audit cheap while including both channels.
    probe = samples[start_frame * 2 : end_frame * 2 : 64]
    return math.sqrt(sum(float(sample) ** 2 for sample in probe) / max(1, len(probe))) / 32768


def write_wave(path: Path, samples: array.array, rate: int) -> None:
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(samples.tobytes())


def make_loop(samples: array.array, rate: int, start: float, end: float, overlap: float) -> array.array:
    total_frames = len(samples) // 2
    first_frame = round(start * rate)
    last_frame = round(end * rate)
    overlap_frames = round(overlap * rate)
    if not (0 < first_frame < last_frame - 2 * overlap_frames < total_frames):
        raise ValueError("Invalid loop boundaries")
    selection = samples[first_frame * 2 : last_frame * 2]
    output = array.array("h", selection[overlap_frames * 2 : -overlap_frames * 2])
    selection_frames = len(selection) // 2
    for frame in range(overlap_frames):
        phase = frame / max(1, overlap_frames - 1)
        tail_gain = math.cos(phase * math.pi / 2)
        head_gain = math.sin(phase * math.pi / 2)
        for channel in range(2):
            tail = selection[(selection_frames - overlap_frames + frame) * 2 + channel]
            head = selection[frame * 2 + channel]
            mixed = round(tail * tail_gain + head * head_gain)
            output.append(max(-32768, min(32767, mixed)))
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true", help="Write looped AAC gameplay copies")
    args = parser.parse_args()
    report: dict[str, dict[str, object]] = {}
    originals = REVIEW / "originals"
    if args.render:
        originals.mkdir(parents=True, exist_ok=True)
        RUNTIME.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="mistport-battle-music-four-") as temporary:
        temp = Path(temporary)
        for slug, (original_name, runtime_name, start, end, overlap) in TRACKS.items():
            source = DOWNLOADS / original_name
            if not source.is_file():
                raise FileNotFoundError(source)
            if args.render:
                shutil.copy2(source, originals / original_name)
            samples, rate = decode(source, temp / f"{slug}.wav")
            duration = len(samples) / 2 / rate
            sections = {
                f"{time:.1f}": round(rms(samples, rate, time, 2.0), 4)
                for time in (0, 2, 4, 6, 10, 30, max(0, duration - 12), max(0, duration - 8), max(0, duration - 4), max(0, duration - 2))
            }
            info: dict[str, object] = {"source": original_name, "duration": round(duration, 3), "rms_2s": sections}
            if args.render:
                if end >= duration:
                    raise ValueError(f"Loop end beyond duration: {slug}")
                loop = make_loop(samples, rate, start, end, overlap)
                wav_path = temp / f"{slug}-loop.wav"
                write_wave(wav_path, loop, rate)
                destination = RUNTIME / runtime_name
                subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "192000", str(wav_path), str(destination)], check=True)
                info.update({
                    "runtime": runtime_name,
                    "start": start, "end": end, "crossfade": overlap,
                    "loop_duration": round(len(loop) / 2 / rate, 3),
                    "seam_delta": [loop[-2] - loop[0], loop[-1] - loop[1]],
                    "loop_rms": round(rms(loop, rate, 0, len(loop) / 2 / rate), 4),
                    "clipped_samples": sum(abs(sample) >= 32767 for sample in loop),
                    "bytes": destination.stat().st_size,
                })
            report[slug] = info
            print(slug, json.dumps(info, ensure_ascii=False))

    if args.render:
        (REVIEW / "music-prep-report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
