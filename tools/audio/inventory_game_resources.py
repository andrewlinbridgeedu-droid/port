#!/usr/bin/env python3
"""Inventory authored and runtime game resources without traversing archive links.

Generated Xcode/Unity builds, caches, backups and historical preview pages are
excluded deliberately: they are not independent active game assets.  Symlinks
inside selected roots are recorded but never followed.
"""

from __future__ import annotations

import csv
import os
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/spell-audio-20260924"
ROOTS = {
    "unity_authoring": "UnityBattleSource/Assets",
    "ios_app": "mistport-ios/Mistport",
    "source_art": "ArtSource",
}
SKIP_DIRS = {".git", "build", "Build", "DerivedData", "Library", "obj", "bin"}


def role(relative: str, group: str) -> str:
    if group == "source_art":
        return "art_source_not_necessarily_runtime"
    if relative.startswith("UnityBattleSource/Assets/Resources/"):
        return "unity_resources_addressable"
    if relative.startswith("UnityBattleSource/Assets/"):
        return "unity_project_asset"
    if relative.startswith("mistport-ios/Mistport/Audio/"):
        return "ios_audio_candidate"
    if relative.startswith("mistport-ios/Mistport/Assets.xcassets/"):
        return "ios_asset_catalog"
    if relative.startswith("mistport-ios/Mistport/WisteriaMap/"):
        return "ios_map_asset"
    return "ios_source_or_resource"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rows: list[tuple[str, str, str, str, int, str]] = []
    counts: Counter[str] = Counter()
    bytes_by_role: defaultdict[str, int] = defaultdict(int)
    for group, folder in ROOTS.items():
        absolute = ROOT / folder
        for directory, dirs, files in os.walk(absolute, followlinks=False):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
            for name in sorted(files):
                if name == ".DS_Store" or name.endswith(".meta"):
                    continue
                path = Path(directory) / name
                relative = path.relative_to(ROOT).as_posix()
                current_role = role(relative, group)
                if path.is_symlink():
                    rows.append((relative, group, current_role, path.suffix.lower(), 0, "symlink-not-followed"))
                    continue
                if not path.is_file():
                    continue
                size = path.stat().st_size
                rows.append((relative, group, current_role, path.suffix.lower(), size, "local"))
                counts[current_role] += 1
                bytes_by_role[current_role] += size
    with (OUT / "resource-inventory.tsv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file, delimiter="\t")
        writer.writerow(("relative_path", "group", "role", "extension", "bytes", "storage"))
        writer.writerows(rows)
    with (OUT / "resource-summary.tsv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file, delimiter="\t")
        writer.writerow(("role", "files", "bytes"))
        for current_role in sorted(counts):
            writer.writerow((current_role, counts[current_role], bytes_by_role[current_role]))
    print(f"Inventoried {len(rows)} source/runtime resource paths; no archive symlinks followed")


if __name__ == "__main__":
    main()
