#!/bin/sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$root"
python3 scripts/check_institutions_art_baseline.py
# The current art must already have a matching export; no implicit export.
MISTPORT_AUTO_EXPORT_UNITY=0 sh scripts/check_unity_export_freshness.sh
out="$root/.build/institutions-device"
mkdir -p "$out"
MISTPORT_AUTO_EXPORT_UNITY=0 xcodebuild -project mistport-ios/Mistport.xcodeproj -scheme Mistport \
  -configuration Debug -sdk iphoneos -destination generic/platform=iOS \
  -derivedDataPath "$out" -jobs 3 MISTPORT_APP_BUNDLE_IDENTIFIER=local.mistport.institutions \
  INFOPLIST_KEY_CFBundleDisplayName='雾港·机构试玩' CURRENT_PROJECT_VERSION=171.7 \
  -allowProvisioningUpdates build > "$out/build.log" 2>&1
printf '%s\n' "$out/Build/Products/Debug-iphoneos/Mistport.app"
