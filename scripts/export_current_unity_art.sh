#!/bin/sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$root"
python3 scripts/check_institutions_art_baseline.py
python3 - <<'PY'
from pathlib import Path
import shutil
root = Path.cwd()
project = root / '.build/current-art-unity'
project.mkdir(parents=True, exist_ok=True)
marker = project / '.mistport-art-export-origin'
known_project = marker.is_file() and marker.read_text().strip() == str(root)
for name in ['Assets', 'ProjectSettings', 'Packages', 'BuildSupport']:
    source = root / 'UnityBattleSource' / name
    target = project / name
    if target.is_symlink():
        raise SystemExit(f'Physical source copy required for Burst: {target}')
    elif target.exists():
        if not known_project:
            raise SystemExit(f'Refusing to replace unregistered export project content: {target}')
        shutil.rmtree(target)
    shutil.copytree(source, target)
marker.write_text(str(root) + '\n')
PY
unity_bin="${MISTPORT_UNITY_BIN:-/Applications/Unity/Hub/Editor/6000.3.20f1/Unity.app/Contents/MacOS/Unity}"
log="${MISTPORT_UNITY_EXPORT_LOG:-$root/.build/current-art-unity-export.log}"
MISTPORT_UNITY_IOS_OUTPUT="$root/mistport-ios/UnityBuild" "$unity_bin" \
  -batchmode -nographics -quit -projectPath "$root/.build/current-art-unity" \
  -executeMethod ExportIOSLibrary.Export -logFile "$log"
MISTPORT_AUTO_EXPORT_UNITY=0 sh scripts/check_unity_export_freshness.sh
