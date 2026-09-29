#!/bin/bash
# Builds build/HarborHarness.app for the iOS Simulator from the app's own
# CityLivingScene.swift and the city assets in the app's asset catalog.
set -e
H="$(cd "$(dirname "$0")" && pwd)"
APPSRC="$H/../../../mistport-ios/Mistport"
B="$H/build"; APP="$B/HarborHarness.app"
rm -rf "$APP" "$B/Assets.xcassets"; mkdir -p "$APP" "$B/Assets.xcassets"
echo '{"info":{"author":"xcode","version":1}}' > "$B/Assets.xcassets/Contents.json"
for d in "$APPSRC"/Assets.xcassets/City*.imageset; do
  cp -R "$d" "$B/Assets.xcassets/"
done
cp "$H/Info.plist" "$APP/Info.plist"
xcrun actool "$B/Assets.xcassets" --compile "$APP" --platform iphonesimulator --minimum-deployment-target 17.0 \
  --target-device iphone --output-partial-info-plist "$B/partial.plist" >/dev/null
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios17.0-simulator -parse-as-library -D DEBUG -Onone \
  "$H/Harness.swift" "$APPSRC/CityLivingScene.swift" "$APPSRC/CityLandmarkPlaque.swift" "$APPSRC/CityAmbience.swift" -o "$APP/HarborHarness"
cp -R "$APPSRC/Audio/Ambience" "$APP/Ambience"
codesign -s - --force "$APP" >/dev/null 2>&1 || true
echo built "$APP"
