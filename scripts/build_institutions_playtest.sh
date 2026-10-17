#!/bin/sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$root"
python3 scripts/check_institutions_art_baseline.py
# The current art must already have a matching export; no implicit export.
MISTPORT_AUTO_EXPORT_UNITY=0 sh scripts/check_unity_export_freshness.sh
out="$root/.build/institutions-device"
mkdir -p "$out"
# Release with the DEBUG condition kept (2026-10-17, iPhone 13: 好卡): Swift -O and IL2CPP/C++
# optimized (Debug built the Unity game code unoptimized), while every #if DEBUG path the
# playtest relies on stays (its save suite, developer tools, review arguments).
MISTPORT_AUTO_EXPORT_UNITY=0 xcodebuild -project mistport-ios/Mistport.xcodeproj -scheme Mistport \
  -configuration Release -sdk iphoneos -destination generic/platform=iOS SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG \
  -derivedDataPath "$out" -jobs 3 MISTPORT_APP_BUNDLE_IDENTIFIER=local.mistport.institutions \
  CURRENT_PROJECT_VERSION=171.7 \
  -allowProvisioningUpdates build > "$out/build.log" 2>&1
printf '%s\n' "$out/Build/Products/Release-iphoneos/Mistport.app"
