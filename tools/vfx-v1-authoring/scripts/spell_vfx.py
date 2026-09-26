#!/usr/bin/env python3
"""Deterministic authoring and acceptance helper for Mindstone VFX V1."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


SKILL_ROOT = Path(__file__).resolve().parent.parent
PRESET_ROOT = SKILL_ROOT / "assets" / "presets"
RESERVED_IDS = {"fireball", "sword"}
ARCHETYPES = {"projectile", "slash", "burst", "beam", "aura", "storm", "summon"}
BACKENDS = {"effekseer", "prefab", "spriteSequence", "ribbon", "extension"}
ANCHORS = {"source", "target", "weapon", "mouth", "impact", "ground", "motion"}
ROLES = {"core", "direction", "trail", "impact-front", "impact-back", "debris", "smoke", "ground", "accent"}

ROOT_KEYS = {"schema", "id", "displayName", "archetype", "seed", "timeline", "anchors", "behavior", "layers", "capture", "cleanupSeconds", "showcase"}
TIMELINE_KEYS = {"windup", "travel", "impact", "decay"}
ANCHOR_KEYS = {"origin", "target", "impact", "ground", "originOffset", "targetOffset", "impactOffset", "groundOffset"}
BEHAVIOR_KEYS = {"path", "arcHeight", "startScale", "endScale", "impactScale", "tracking", "beamWidth", "orbitRadius", "spinDegrees", "extensionType"}
LAYER_KEYS = {"name", "backend", "asset", "role", "anchor", "start", "end", "color", "scale", "startScale", "endScale", "width", "pointCount", "renderQueue", "sortingOrder", "seedOffset", "fps", "loop", "faceCamera", "frontOfTarget", "extensionType"}
CAPTURE_KEYS = {"times", "device", "targetFps"}
SHOWCASE_KEYS = {"sourceActor", "source", "target"}


class SpellError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def ensure_relative_to_repo(repo: Path, path: Path, label: str) -> None:
    try:
        path.resolve().relative_to(repo.resolve())
    except ValueError as exc:
        raise SpellError(f"{label} must stay inside the repository: {path}") from exc


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SpellError(f"Cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SpellError(f"Expected JSON object: {path}")
    return value


def repo_root(value: str) -> Path:
    path = Path(value).expanduser().resolve()
    marker = path / "UnityBattleSource" / "ProjectSettings" / "ProjectVersion.txt"
    if not marker.is_file():
        raise SpellError(f"Not a Mindstone repository (missing {marker})")
    return path


def resource_root(repo: Path) -> Path:
    return repo / "UnityBattleSource" / "Assets" / "Resources"


def spell_path(repo: Path, spell_id: str) -> Path:
    return resource_root(repo) / "Mindstone" / "VFXV1" / "Spells" / spell_id / "spell.json"


def registry_path(repo: Path, spell_id: str) -> Path:
    return resource_root(repo) / "Mindstone" / "VFXV1" / "Registry" / f"{spell_id}.json"


def authoring_path(repo: Path, spell_id: str) -> Path:
    return repo / "UnityBattleSource" / "Assets" / "Mindstone" / "VFXV1" / "Authoring" / spell_id


def baseline_root(repo: Path) -> Path:
    return repo / "UnityBattleSource" / "VFXBaselines"


def assert_keys(value: dict[str, Any], expected: set[str], label: str, errors: list[str]) -> None:
    missing = expected - value.keys()
    unknown = value.keys() - expected
    if missing:
        errors.append(f"{label}: missing {', '.join(sorted(missing))}")
    if unknown:
        errors.append(f"{label}: unknown {', '.join(sorted(unknown))}")


def is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def check_vec(value: Any, label: str, errors: list[str], color: bool = False) -> None:
    expected = 4 if color else 3
    if not isinstance(value, list) or len(value) != expected or not all(is_number(item) for item in value):
        errors.append(f"{label}: expected {expected} numbers")
        return
    if color and any(item < 0 or item > 1 for item in value):
        errors.append(f"{label}: color channels must be in [0, 1]")


def validate_resource(repo: Path, backend: str, asset: str, label: str, errors: list[str]) -> None:
    if backend in {"ribbon", "extension"} and not asset:
        return
    if not asset:
        errors.append(f"{label}: backend {backend} requires asset")
        return
    root = resource_root(repo)
    base = root / asset
    suffixes = {
        "effekseer": [".asset"],
        "prefab": [".prefab"],
        "spriteSequence": [".png", ".jpg", ".jpeg", ".asset"],
        "ribbon": [".png", ".jpg", ".jpeg", ".asset"],
    }.get(backend, [])
    if base.is_dir() or any(base.with_suffix(suffix).is_file() for suffix in suffixes):
        return
    errors.append(f"{label}: Resources asset not found: {asset}")


def validate_spec(repo: Path, spec: dict[str, Any], source: Path) -> list[str]:
    errors: list[str] = []
    assert_keys(spec, ROOT_KEYS, "root", errors)
    spell_id = spec.get("id")
    if spec.get("schema") != 1:
        errors.append("root.schema: expected 1")
    if not isinstance(spell_id, str) or not spell_id or not spell_id[0].isalpha() or any(ch not in "abcdefghijklmnopqrstuvwxyz0123456789-" for ch in spell_id):
        errors.append("root.id: use lowercase letters, digits, and hyphens")
    elif spell_id in RESERVED_IDS:
        errors.append(f"root.id: {spell_id} is a locked legacy ID")
    if spec.get("archetype") not in ARCHETYPES:
        errors.append("root.archetype: unsupported archetype")
    if not isinstance(spec.get("seed"), int) or spec.get("seed", 0) < 1:
        errors.append("root.seed: expected positive integer")

    timeline = spec.get("timeline")
    total = 0.0
    if not isinstance(timeline, dict):
        errors.append("root.timeline: expected object")
    else:
        assert_keys(timeline, TIMELINE_KEYS, "timeline", errors)
        for key in TIMELINE_KEYS:
            value = timeline.get(key)
            if not is_number(value) or value < 0:
                errors.append(f"timeline.{key}: expected nonnegative number")
            else:
                total += float(value)
        if total <= 0:
            errors.append("timeline: total duration must be positive")

    anchors = spec.get("anchors")
    if not isinstance(anchors, dict):
        errors.append("root.anchors: expected object")
    else:
        assert_keys(anchors, ANCHOR_KEYS, "anchors", errors)
        for key in ("origin", "target", "impact", "ground"):
            if anchors.get(key) not in ANCHORS:
                errors.append(f"anchors.{key}: unsupported anchor")
        for key in ("originOffset", "targetOffset", "impactOffset", "groundOffset"):
            check_vec(anchors.get(key), f"anchors.{key}", errors)

    behavior = spec.get("behavior")
    if not isinstance(behavior, dict):
        errors.append("root.behavior: expected object")
    else:
        assert_keys(behavior, BEHAVIOR_KEYS, "behavior", errors)
        if behavior.get("path") not in {"linear", "bezier", "stationary", "orbit"}:
            errors.append("behavior.path: unsupported path")
        for key in ("arcHeight", "startScale", "endScale", "impactScale", "tracking", "beamWidth", "orbitRadius", "spinDegrees"):
            if not is_number(behavior.get(key)):
                errors.append(f"behavior.{key}: expected number")

    layers = spec.get("layers")
    if not isinstance(layers, list) or not layers:
        errors.append("root.layers: expected nonempty array")
    else:
        names: set[str] = set()
        roles: set[str] = set()
        for index, layer in enumerate(layers):
            label = f"layers[{index}]"
            if not isinstance(layer, dict):
                errors.append(f"{label}: expected object")
                continue
            assert_keys(layer, LAYER_KEYS, label, errors)
            name = layer.get("name")
            if not isinstance(name, str) or not name:
                errors.append(f"{label}.name: expected string")
            elif name in names:
                errors.append(f"{label}.name: duplicate {name}")
            names.add(name)
            backend = layer.get("backend")
            if backend not in BACKENDS:
                errors.append(f"{label}.backend: unsupported backend")
                continue
            if layer.get("role") not in ROLES:
                errors.append(f"{label}.role: unsupported role")
            else:
                roles.add(layer["role"])
            if layer.get("anchor") not in ANCHORS:
                errors.append(f"{label}.anchor: unsupported anchor")
            start, end = layer.get("start"), layer.get("end")
            if not is_number(start) or not is_number(end) or not 0 <= start < end <= 1:
                errors.append(f"{label}: require 0 <= start < end <= 1")
            check_vec(layer.get("color"), f"{label}.color", errors, color=True)
            check_vec(layer.get("scale"), f"{label}.scale", errors)
            if backend == "extension" and not layer.get("extensionType"):
                errors.append(f"{label}.extensionType: required for extension")
            validate_resource(repo, backend, str(layer.get("asset", "")), label, errors)
        if "core" not in roles:
            errors.append("root.layers: commercial candidate requires a core role")
        if spec.get("archetype") in {"projectile", "slash", "beam", "summon"} and not roles.intersection({"direction", "trail"}):
            errors.append("root.layers: moving archetype requires direction or trail role")
        if not roles.intersection({"impact-front", "impact-back"}):
            errors.append("root.layers: commercial candidate requires impact-front or impact-back")

    capture = spec.get("capture")
    if not isinstance(capture, dict):
        errors.append("root.capture: expected object")
    else:
        assert_keys(capture, CAPTURE_KEYS, "capture", errors)
        times = capture.get("times")
        if not isinstance(times, list) or len(times) != 5 or not all(is_number(item) for item in times):
            errors.append("capture.times: expected exactly five numbers")
        elif any(times[index] >= times[index + 1] for index in range(4)):
            errors.append("capture.times: must be strictly increasing")
        elif times[0] <= 0 or times[-1] > total + 0.0001:
            errors.append("capture.times: each time must be inside the spell timeline")
        if capture.get("device") != "iPhone 13" or capture.get("targetFps") != 60:
            errors.append("capture: baseline must be iPhone 13 at 60 fps")

    showcase = spec.get("showcase")
    if not isinstance(showcase, dict):
        errors.append("root.showcase: expected object")
    else:
        assert_keys(showcase, SHOWCASE_KEYS, "showcase", errors)
        if showcase.get("sourceActor") not in {"clockguard", "hellhound", "player"}:
            errors.append("showcase.sourceActor: unsupported actor")
        check_vec(showcase.get("source"), "showcase.source", errors)
        check_vec(showcase.get("target"), "showcase.target", errors)

    cleanup = spec.get("cleanupSeconds")
    if not is_number(cleanup) or not 0 <= cleanup <= 3:
        errors.append("root.cleanupSeconds: expected number in [0, 3]")
    if isinstance(spell_id, str) and source.stem == "spell" and source.parent.name != spell_id:
        errors.append(f"root.id: {spell_id} does not match directory {source.parent.name}")
    return errors


def all_registry_entries(repo: Path) -> list[tuple[Path, dict[str, Any]]]:
    root = resource_root(repo) / "Mindstone" / "VFXV1" / "Registry"
    return [(path, read_json(path)) for path in sorted(root.glob("*.json"))]


def resolve_registry_spec(repo: Path, entry: dict[str, Any]) -> Path:
    resource = entry.get("spec")
    if not isinstance(resource, str) or not resource:
        raise SpellError("Registry entry requires nonempty spec")
    return resource_root(repo) / f"{resource}.json"


def validate_repository(repo: Path, only_spell: str | None = None) -> dict[str, Any]:
    errors: list[str] = []
    entries = all_registry_entries(repo)
    seen: dict[str, Path] = {}
    checked: list[str] = []
    for path, entry in entries:
        expected = {"schema", "id", "spec"}
        unknown = entry.keys() - expected
        missing = expected - entry.keys()
        if unknown or missing or entry.get("schema") != 1:
            errors.append(f"{path}: invalid registry keys/schema")
            continue
        spell_id = entry.get("id")
        if only_spell and spell_id != only_spell:
            continue
        if spell_id in seen:
            errors.append(f"Duplicate registry id {spell_id}: {seen[spell_id]} and {path}")
            continue
        seen[spell_id] = path
        try:
            target = resolve_registry_spec(repo, entry)
            spec = read_json(target)
        except SpellError as exc:
            errors.append(str(exc))
            continue
        if spec.get("id") != spell_id:
            errors.append(f"{path}: id does not match {target}")
        errors.extend(f"{target}: {item}" for item in validate_spec(repo, spec, target))
        checked.append(str(spell_id))
    if only_spell and only_spell not in checked:
        errors.append(f"Spell is not registered: {only_spell}")
    return {"ok": not errors, "checked": checked, "errors": errors}


def base_spec(spell_id: str, display_name: str, fragment: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": 1,
        "id": spell_id,
        "displayName": display_name,
        "archetype": fragment["archetype"],
        "seed": 73013,
        "timeline": fragment["timeline"],
        "anchors": {
            "origin": "source", "target": "target", "impact": "impact", "ground": "ground",
            "originOffset": [0, 0, 0], "targetOffset": [0, 0, 0], "impactOffset": [0, 0, 0], "groundOffset": [0, 0, 0]
        },
        "behavior": fragment["behavior"],
        "layers": fragment["layers"],
        "capture": fragment["capture"],
        "cleanupSeconds": fragment.get("cleanupSeconds", 0.35),
        "showcase": fragment.get("showcase", {"sourceActor": "clockguard", "source": [-3.45, 1.65, 3.8], "target": [-3.45, 0.66, 3.8]})
    }


def command_new(args: argparse.Namespace) -> None:
    repo = repo_root(args.repo)
    if args.id in RESERVED_IDS:
        raise SpellError(f"{args.id} is a locked legacy ID")
    preset = PRESET_ROOT / f"{args.preset}.json"
    if not preset.is_file():
        raise SpellError(f"Unknown preset: {args.preset}")
    targets = [spell_path(repo, args.id), registry_path(repo, args.id), authoring_path(repo, args.id)]
    if any(path.exists() for path in targets):
        raise SpellError(f"Refusing to overwrite existing spell: {args.id}")
    spec = base_spec(args.id, args.display_name, read_json(preset))
    registry = {"schema": 1, "id": args.id, "spec": f"Mindstone/VFXV1/Spells/{args.id}/spell"}
    provenance = {
        "schema": 1, "spell": args.id, "brief": args.request,
        "preset": args.preset, "owner": "mindstone-create-spell-vfx",
        "assets": [{"path": layer["asset"], "origin": "existing-project-resource" if layer["asset"] else "procedural-runtime"} for layer in spec["layers"]]
    }
    spec_target = spell_path(repo, args.id)
    registry_target = registry_path(repo, args.id)
    provenance_target = authoring_path(repo, args.id) / "provenance.json"
    write_json(spec_target, spec)
    write_json(registry_target, registry)
    write_json(provenance_target, provenance)
    manifest_target = authoring_path(repo, args.id) / "generated.manifest.json"
    files = {}
    for target in (spec_target, registry_target, provenance_target):
        files[str(target.relative_to(repo))] = sha256(target)
    write_json(manifest_target, {"schema": 1, "owner": "mindstone-create-spell-vfx", "spell": args.id, "files": files})
    print(f"Created candidate {args.id}")
    print(spec_target)


def unity_binary() -> Path:
    override = os.environ.get("MISTPORT_UNITY_BIN")
    candidates = [Path(override).expanduser()] if override else [
        Path("/Applications/Unity/Hub/Editor/6000.3.20f1/Unity.app/Contents/MacOS/Unity"),
        Path("/Users/andrewlin/.unity/bin/unity"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    raise SpellError("Unity executable not found: " + ", ".join(str(path) for path in candidates))


def run_unity_validate(repo: Path, spell: str | None, report: Path) -> None:
    log = report.with_suffix(".unity.log")
    command = [str(unity_binary()), "-batchmode", "-quit", "-projectPath", str(repo / "UnityBattleSource"), "-executeMethod", "Mindstone.VFXV1.SpellBatch.Validate", "-vfxReport", str(report), "-logFile", str(log)]
    if spell:
        command.extend(["-vfxSpell", spell])
    completed = subprocess.run(command, text=True)
    if completed.returncode != 0:
        raise SpellError(f"Unity validation failed ({completed.returncode}); see {log}")


def command_validate(args: argparse.Namespace) -> None:
    repo = repo_root(args.repo)
    report = validate_repository(repo, args.spell)
    output = Path(args.report).expanduser().resolve() if args.report else repo / "artifacts" / "vfx-v1" / f"validate-{args.spell or 'all'}.json"
    write_json(output, {"validator": "python", **report})
    if not report["ok"]:
        for error in report["errors"]:
            print(f"ERROR {error}", file=sys.stderr)
        raise SpellError(f"Validation failed; report: {output}")
    if not args.skip_unity:
        run_unity_validate(repo, args.spell, output.with_name(output.stem + "-unity.json"))
    print(f"Validated {len(report['checked'])} spell(s): {', '.join(report['checked']) or '(none)'}")
    print(output)


def source_mtime(repo: Path) -> float:
    roots = [repo / "UnityBattleSource" / "Assets" / "Scripts", repo / "UnityBattleSource" / "Assets" / "Mindstone", resource_root(repo) / "Mindstone"]
    return max((path.stat().st_mtime for root in roots if root.exists() for path in root.rglob("*") if path.is_file()), default=0)


def build_preview(repo: Path, output: Path, spell: str) -> Path:
    executable = output / "Contents" / "MacOS"
    binaries = list(executable.glob("*")) if executable.is_dir() else []
    if not binaries or max(path.stat().st_mtime for path in binaries) < source_mtime(repo):
        log = repo / "artifacts" / "vfx-v1" / "preview-build.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        command = [str(unity_binary()), "-batchmode", "-quit", "-projectPath", str(repo / "UnityBattleSource"), "-executeMethod", "BuildRuntimePreview.BuildMacPlayer", "-previewPlayerOutput", str(output), "-previewEffect", spell, "-logFile", str(log)]
        if subprocess.run(command).returncode != 0:
            raise SpellError(f"Preview build failed; see {log}")
        binaries = list(executable.glob("*"))
    if not binaries:
        raise SpellError(f"Preview executable missing in {output}")
    return binaries[0]


def command_capture(args: argparse.Namespace) -> None:
    repo = repo_root(args.repo)
    report = validate_repository(repo, args.spell)
    if not report["ok"]:
        raise SpellError("Validate the spell before capture: " + "; ".join(report["errors"]))
    player = Path(args.player).expanduser().resolve() if args.player else Path("/private/tmp/mindstone-vfx-v1-preview.app")
    binary = build_preview(repo, player, args.spell)
    prefix = f"mindstone-vfx-board-{args.spell}-stage-"
    for old in Path("/private/tmp").glob(prefix + "*.bmp"):
        old.unlink()
    runtime_log = repo / "artifacts" / "vfx-v1" / f"capture-{args.spell}.log"
    runtime_log.parent.mkdir(parents=True, exist_ok=True)
    runtime_stream = runtime_log.open("w", encoding="utf-8")
    process = subprocess.Popen(
        [str(binary), f"--preview-vfx-board={args.spell}", "--capture-vfx-board-review"],
        stdout=runtime_stream,
        stderr=subprocess.STDOUT,
        text=True,
    )
    deadline = time.monotonic() + args.timeout
    frames: list[Path] = []
    try:
        while time.monotonic() < deadline:
            frames = sorted(Path("/private/tmp").glob(prefix + "*.bmp"))
            if len(frames) == 5:
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    pass
                break
            if process.poll() is not None:
                raise SpellError(f"Preview exited before five frames ({len(frames)})")
            time.sleep(0.2)
    finally:
        if process.poll() is None:
            process.send_signal(signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        runtime_stream.close()
    if len(frames) != 5:
        raise SpellError(f"Expected five frames, found {len(frames)}")
    target = baseline_root(repo) / ".candidates" / args.spell
    target.mkdir(parents=True, exist_ok=True)
    for old in target.glob("stage-*.*"):
        old.unlink()
    for index, frame in enumerate(frames, 1):
        png = target / f"stage-{index}.png"
        result = subprocess.run(["sips", "-s", "format", "png", str(frame), "--out", str(png)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode != 0:
            shutil.copy2(frame, target / f"stage-{index}.bmp")
        frame.unlink()
    spec = read_json(spell_path(repo, args.spell))
    write_json(target / "candidate.json", {"schema": 1, "spell": args.spell, "status": "candidate", "captureTimes": spec["capture"]["times"], "frames": [path.name for path in sorted(target.glob("stage-*.*"))]})
    print(target)


def command_showcase(args: argparse.Namespace) -> None:
    repo = repo_root(args.repo)
    report = validate_repository(repo, args.spell)
    if not report["ok"]:
        raise SpellError("Validate the spell before showcase: " + "; ".join(report["errors"]))
    player = Path(args.player).expanduser().resolve() if args.player else Path("/private/tmp/mindstone-vfx-v1-preview.app")
    binary = build_preview(repo, player, args.spell)
    runtime_log = repo / "artifacts" / "vfx-v1" / f"showcase-{args.spell}.log"
    runtime_log.parent.mkdir(parents=True, exist_ok=True)
    with runtime_log.open("w", encoding="utf-8") as stream:
        process = subprocess.Popen(
            [str(binary), f"--preview-vfx-board={args.spell}"],
            stdout=stream,
            stderr=subprocess.STDOUT,
            text=True,
        )
    print(f"Showcase started (pid {process.pid}); use PLAY/REPLAY and SLOW x0.30")
    print(runtime_log)


def verify_manifest(repo: Path, spell_id: str) -> list[str]:
    manifest = authoring_path(repo, spell_id) / "generated.manifest.json"
    if not manifest.is_file():
        return [f"Missing generation manifest for {spell_id}"]
    value = read_json(manifest)
    errors = []
    for relative, expected in value.get("files", {}).items():
        path = repo / relative
        try:
            ensure_relative_to_repo(repo, path, "Generated file")
        except SpellError as exc:
            errors.append(str(exc))
            continue
        if not path.is_file():
            errors.append(f"Missing generated file: {relative}")
        elif sha256(path) != expected:
            errors.append(f"Generated file was hand-edited: {relative}")
    return errors


def command_refresh_manifest(args: argparse.Namespace) -> None:
    repo = repo_root(args.repo)
    manifest_path = authoring_path(repo, args.spell) / "generated.manifest.json"
    if not manifest_path.is_file():
        raise SpellError(f"Missing generation manifest: {manifest_path}")
    value = read_json(manifest_path)
    files = value.get("files")
    if not isinstance(files, dict) or not files:
        raise SpellError("Generation manifest has no owned files")
    if not args.accept_hand_edits:
        errors = verify_manifest(repo, args.spell)
        if errors:
            raise SpellError("Refusing changed generated files; review them, then pass --accept-hand-edits: " + "; ".join(errors))
    refreshed = {}
    for relative in files:
        path = repo / relative
        ensure_relative_to_repo(repo, path, "Generated file")
        if not path.is_file():
            raise SpellError(f"Missing generated file: {relative}")
        refreshed[relative] = sha256(path)
    value["files"] = refreshed
    write_json(manifest_path, value)
    print(manifest_path)


def command_lock(args: argparse.Namespace) -> None:
    repo = repo_root(args.repo)
    if args.spell in RESERVED_IDS:
        raise SpellError("Legacy locks are maintained by the existing VFX skill")
    lock_dir = baseline_root(repo) / args.spell
    if lock_dir.exists():
        raise SpellError(f"Refusing to replace existing lock: {lock_dir}")
    errors = validate_repository(repo, args.spell)["errors"] + verify_manifest(repo, args.spell)
    if errors:
        raise SpellError("Cannot lock: " + "; ".join(errors))
    device_report = Path(args.device_report).expanduser().resolve()
    ensure_relative_to_repo(repo, device_report, "Device report")
    device = read_json(device_report)
    required_device_keys = {
        "schema", "spell", "device", "targetFps", "averageFps", "p95FrameTimeMs",
        "maxParticles", "maxDrawCalls", "peakMemoryMB", "cleanup"
    }
    missing_device_keys = required_device_keys - device.keys()
    if missing_device_keys:
        raise SpellError("Device report is incomplete: " + ", ".join(sorted(missing_device_keys)))
    if device.get("schema") != 1 or device.get("spell") != args.spell:
        raise SpellError("Device report schema/spell does not match the candidate")
    if (device.get("device") != "iPhone 13"
            or int(device.get("targetFps", 0)) != 60
            or float(device.get("averageFps", 0)) < 55
            or float(device.get("p95FrameTimeMs", 999)) > 20
            or int(device.get("maxParticles", -1)) < 0
            or int(device.get("maxDrawCalls", -1)) < 0
            or float(device.get("peakMemoryMB", -1)) < 0):
        raise SpellError("Device report must be iPhone 13 at 60 fps, average >=55 fps, p95 <=20 ms, with nonnegative particle/draw-call/memory metrics")
    cleanup = device.get("cleanup")
    orphan_keys = ("orphanRoots", "orphanLights", "orphanEmitters", "orphanMaterials", "orphanEffekseerHandles")
    if not isinstance(cleanup, dict) or set(cleanup) != {"natural", "interrupt", "replay"}:
        raise SpellError("Device report cleanup must contain natural, interrupt, and replay results")
    for scenario in ("natural", "interrupt", "replay"):
        result = cleanup.get(scenario)
        if not isinstance(result, dict) or any(int(result.get(key, -1)) != 0 for key in orphan_keys):
            raise SpellError(f"Device report must show zero VFX leftovers after {scenario}")
    candidate = baseline_root(repo) / ".candidates" / args.spell
    frames = sorted(candidate.glob("stage-*.png"))
    if len(frames) != 5:
        raise SpellError("Candidate must contain exactly five PNG frames")
    lock_dir.mkdir(parents=True)
    for frame in frames:
        shutil.copy2(frame, lock_dir / frame.name)
    sources = [spell_path(repo, args.spell), registry_path(repo, args.spell)]
    write_json(lock_dir / "lock.json", {
        "schema": 1, "spell": args.spell, "status": "approved", "approvedBy": args.approved_by,
        "deviceReport": str(device_report.relative_to(repo)),
        "sources": {str(path.relative_to(repo)): sha256(path) for path in sources},
        "frames": {frame.name: sha256(frame) for frame in sorted(lock_dir.glob("stage-*.png"))}
    })
    print(lock_dir)


def command_regress(args: argparse.Namespace) -> None:
    repo = repo_root(args.repo)
    errors: list[str] = []
    validation = validate_repository(repo)
    errors.extend(validation["errors"])
    legacy = baseline_root(repo) / "legacy-approved.json"
    if not legacy.is_file():
        errors.append(f"Missing legacy lock: {legacy}")
    else:
        legacy_value = read_json(legacy)
        board = repo / "UnityBattleSource" / "Assets" / "Scripts" / "MistportVFXShowcaseBoard.cs"
        board_text = board.read_text(encoding="utf-8") if board.is_file() else ""
        for effect in legacy_value.get("effects", []):
            for relative, expected in effect.get("assets", {}).items():
                path = repo / relative
                if not path.is_file() or sha256(path) != expected:
                    errors.append(f"Legacy approved asset drift: {relative}")
            capture_times = effect.get("captureTimes", [])
            capture_literal = ", ".join(f"{float(value):.2f}f" for value in capture_times)
            if capture_literal not in board_text:
                errors.append(f"Legacy approved five-frame timing drift: {effect.get('id')}")
            implementation = effect.get("implementationRange", {})
            implementation_path = repo / str(implementation.get("path", ""))
            if implementation_path.is_file():
                implementation_text = implementation_path.read_text(encoding="utf-8")
                start_marker = str(implementation.get("start", ""))
                end_marker = str(implementation.get("end", ""))
                try:
                    start_index = implementation_text.index(start_marker)
                    end_index = implementation_text.index(end_marker, start_index)
                    actual = hashlib.sha256(implementation_text[start_index:end_index].encode()).hexdigest()
                    if actual != implementation.get("sha256"):
                        errors.append(f"Legacy approved implementation drift: {effect.get('id')}")
                except ValueError:
                    errors.append(f"Legacy approved implementation markers missing: {effect.get('id')}")
            else:
                errors.append(f"Legacy approved implementation missing: {implementation_path}")
    for lock in sorted(baseline_root(repo).glob("*/lock.json")):
        value = read_json(lock)
        for relative, expected in value.get("sources", {}).items():
            path = repo / relative
            if not path.is_file() or sha256(path) != expected:
                errors.append(f"Locked source drift: {relative}")
        for name, expected in value.get("frames", {}).items():
            path = lock.parent / name
            if not path.is_file() or sha256(path) != expected:
                errors.append(f"Locked frame drift: {path}")
    if errors:
        raise SpellError("Regression failed:\n" + "\n".join(errors))
    print(f"Locked regression passed ({len(validation['checked'])} V1 spell(s))")


def command_inspect(args: argparse.Namespace) -> None:
    repo = repo_root(args.repo)
    entries = all_registry_entries(repo)
    print(f"repo={repo}")
    print(f"unity={unity_binary()}")
    print(f"v1_runtime={(repo / 'UnityBattleSource/Assets/Mindstone/VFXV1').is_dir()}")
    print(f"registered_spells={','.join(str(entry.get('id')) for _, entry in entries) or '(none)'}")
    print("legacy_locked=fireball,sword")
    print("boundary=do not edit approved legacy fireball/sword playback or assets")


def command_report(args: argparse.Namespace) -> None:
    repo = repo_root(args.repo)
    root = baseline_root(repo) / (".candidates" if args.candidate else "")
    path = root / args.spell / ("candidate.json" if args.candidate else "lock.json")
    print(json.dumps(read_json(path), ensure_ascii=False, indent=2))


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="command", required=True)
    inspect_parser = commands.add_parser("inspect")
    inspect_parser.add_argument("--repo", required=True)
    inspect_parser.set_defaults(func=command_inspect)
    new_parser = commands.add_parser("new")
    new_parser.add_argument("--repo", required=True)
    new_parser.add_argument("--id", required=True)
    new_parser.add_argument("--display-name", required=True)
    new_parser.add_argument("--preset", choices=sorted(ARCHETYPES), required=True)
    new_parser.add_argument("--request", required=True)
    new_parser.set_defaults(func=command_new)
    validate_parser = commands.add_parser("validate")
    validate_parser.add_argument("--repo", required=True)
    validate_parser.add_argument("--spell")
    validate_parser.add_argument("--report")
    validate_parser.add_argument("--skip-unity", action="store_true")
    validate_parser.set_defaults(func=command_validate)
    capture_parser = commands.add_parser("capture")
    capture_parser.add_argument("--repo", required=True)
    capture_parser.add_argument("--spell", required=True)
    capture_parser.add_argument("--player")
    capture_parser.add_argument("--timeout", type=float, default=35)
    capture_parser.set_defaults(func=command_capture)
    showcase_parser = commands.add_parser("showcase")
    showcase_parser.add_argument("--repo", required=True)
    showcase_parser.add_argument("--spell", required=True)
    showcase_parser.add_argument("--player")
    showcase_parser.set_defaults(func=command_showcase)
    lock_parser = commands.add_parser("lock")
    lock_parser.add_argument("--repo", required=True)
    lock_parser.add_argument("--spell", required=True)
    lock_parser.add_argument("--approved-by", required=True)
    lock_parser.add_argument("--device-report", required=True)
    lock_parser.set_defaults(func=command_lock)
    regress_parser = commands.add_parser("regress-locked")
    regress_parser.add_argument("--repo", required=True)
    regress_parser.set_defaults(func=command_regress)
    refresh_parser = commands.add_parser("refresh-manifest")
    refresh_parser.add_argument("--repo", required=True)
    refresh_parser.add_argument("--spell", required=True)
    refresh_parser.add_argument("--accept-hand-edits", action="store_true")
    refresh_parser.set_defaults(func=command_refresh_manifest)
    report_parser = commands.add_parser("report")
    report_parser.add_argument("--repo", required=True)
    report_parser.add_argument("--spell", required=True)
    report_parser.add_argument("--candidate", action="store_true")
    report_parser.set_defaults(func=command_report)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        args.func(args)
        return 0
    except SpellError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
