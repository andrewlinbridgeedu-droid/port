#!/bin/zsh
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
# The iOS 18.6 runtime can run this app, but Xcode 26.5 actool requires
# its matching runtime. Reuse only the unchanged, previously built UI catalog.
python3 - <<'PY'
from pathlib import Path
import hashlib,json
root=Path('mistport-ios/Mistport/Assets.xcassets')
manifest=Path('output/player-test-01-15/compiled-ui-assets/source-sha256.json')
expected=json.loads(manifest.read_text())
actual={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
if actual!=expected: raise SystemExit('UI assets changed; install a matching Xcode simulator runtime and rebuild the asset catalog before packaging.')
PY
xcodebuild -project mistport-ios/Mistport.xcodeproj -target Mistport \
  -configuration Debug -sdk iphonesimulator -jobs 2 \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO \
  EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets \
  SYMROOT="$project_root/mistport-ios/build" OBJROOT="$project_root/mistport-ios/build" build
python3 - <<'PY'
from pathlib import Path
import plistlib,shutil
src=Path('output/player-test-01-15/compiled-ui-assets')
dst=Path('mistport-ios/build/Debug-iphonesimulator/Mistport.app')
for p in [src/'Assets.car',*src.glob('AppIcon*.png')]: shutil.copy2(p,dst/p.name)
old=plistlib.loads((src/'previous-app-info.plist').read_bytes())
new=plistlib.loads((dst/'Info.plist').read_bytes())
for key in ['CFBundleIcons','CFBundleIcons~ipad']:
    if key in old: new[key]=old[key]
(dst/'Info.plist').write_bytes(plistlib.dumps(new,fmt=plistlib.FMT_BINARY))
print(dst.resolve())
PY
