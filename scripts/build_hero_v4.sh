#!/bin/sh
# Hero v4 build for this worktree: optional Blender export and Unity import,
# then the Unity iOS export and the Xcode host build for the phone (device) or
# the iOS Simulator (simulator). DerivedData and logs stay on the external SSD.
#
#   scripts/build_hero_v4.sh simulator 169.30 [--blender] [--import]
#   scripts/build_hero_v4.sh device 169.30 [--blender] [--import]
#
# --blender re-exports the model and clips from tools/animation/build_hero_v4.py
# (and implies --import); --import rebuilds the Unity materials and controller.
# Overrides: MISTPORT_BUILD_CACHE, MISTPORT_BUILD_OUT, MISTPORT_UNITY_APP,
# MISTPORT_BLENDER, MISTPORT_SIM_DEVICE (simulator name, default iPhone 17 Pro).
#
# A simulator export replaces mistport-ios/UnityBuild, so a device build always
# re-exports first (this script does). Unity rewrites iPhoneSdkVersion in
# ProjectSettings.asset for a simulator export; the script restores the file.
set -eu
mode="${1:?usage: build_hero_v4.sh device|simulator VERSION [--blender] [--import]}"
version="${2:?usage: build_hero_v4.sh device|simulator VERSION [--blender] [--import]}"
shift 2
case "$mode" in device|simulator) ;; *) echo "mode must be device or simulator" >&2; exit 2 ;; esac
blender=0
import=0
for arg in "$@"; do
    case "$arg" in
        --blender) blender=1; import=1 ;;
        --import) import=1 ;;
        *) echo "unknown option $arg" >&2; exit 2 ;;
    esac
done

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# Kept outside ${...:-...}: sh treats the apostrophe there as a quote.
default_cache="/Volumes/andrew's SSD/Mistport-build-cache"
cache="${MISTPORT_BUILD_CACHE:-$default_cache}"
out="${MISTPORT_BUILD_OUT:-$cache/hero-v4-$(basename "$root")-$mode}"
unity="${MISTPORT_UNITY_APP:-/Applications/Unity/Hub/Editor/6000.3.20f1/Unity.app/Contents/MacOS/Unity}"
blender_bin="${MISTPORT_BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
mkdir -p "$out"
cd "$root"
step() { echo "STEP $1 $(date +%T)"; }

if [ "$blender" = 1 ]; then
    step blender
    "$blender_bin" -b --python tools/animation/build_hero_v4.py -- "$root" --export > "$out/blender-$version.log" 2>&1
    grep -q HERO_V4_EXPORTED "$out/blender-$version.log"
fi
if [ "$import" = 1 ]; then
    step unity-import
    "$unity" -batchmode -quit -projectPath "$root/UnityBattleSource" \
        -executeMethod RefinedHeroV4Import.Build -logFile "$out/import-$version.log" > /dev/null 2>&1
    grep -q HERO_V4_IMPORTED "$out/import-$version.log"
fi

step "unity-ios-$mode"
settings="$root/UnityBattleSource/ProjectSettings/ProjectSettings.asset"
saved="$(mktemp "${TMPDIR:-/tmp}/mistport-project-settings.XXXXXX")"
cp "$settings" "$saved"
trap 'cp "$saved" "$settings"; rm -f "$saved"' EXIT
simulator_flag=""
[ "$mode" = simulator ] && simulator_flag=1
MISTPORT_UNITY_IOS_SIMULATOR="$simulator_flag" MISTPORT_UNITY_IOS_OUTPUT="$root/mistport-ios/UnityBuild" \
    "$unity" -batchmode -quit -projectPath "$root/UnityBattleSource" \
    -executeMethod ExportIOSLibrary.Export -logFile "$out/export-$version.log" > /dev/null 2>&1
grep -q "Build Finished, Result: Success" "$out/export-$version.log"
cp "$saved" "$settings"

step freshness
MISTPORT_AUTO_EXPORT_UNITY=0 sh scripts/check_unity_export_freshness.sh

step xcode
if [ "$mode" = device ]; then
    MISTPORT_AUTO_EXPORT_UNITY=0 xcodebuild -project mistport-ios/Mistport.xcodeproj -scheme Mistport \
        -configuration Debug -sdk iphoneos -destination generic/platform=iOS -derivedDataPath "$out/Derived" \
        -jobs 6 CURRENT_PROJECT_VERSION="$version" -allowProvisioningUpdates build > "$out/build-$version.log" 2>&1
    app="$out/Derived/Build/Products/Debug-iphoneos/Mistport.app"
else
    simulator="${MISTPORT_SIM_DEVICE:-iPhone 17 Pro}"
    MISTPORT_AUTO_EXPORT_UNITY=0 xcodebuild -project mistport-ios/Mistport.xcodeproj -scheme Mistport \
        -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,name=$simulator" \
        -derivedDataPath "$out/Derived" -jobs 6 ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
        CURRENT_PROJECT_VERSION="$version" build > "$out/build-$version.log" 2>&1
    app="$out/Derived/Build/Products/Debug-iphonesimulator/Mistport.app"
fi
grep -q "BUILD SUCCEEDED" "$out/build-$version.log"
echo "BUILT $app"
