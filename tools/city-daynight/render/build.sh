#!/bin/bash
# Builds build/HarborRender.app (macOS) from the app's CityLivingScene.swift
# and the city imagesets of the app's asset catalog.
set -e
H="$(cd "$(dirname "$0")" && pwd)"
APPSRC="$H/../../../mistport-ios/Mistport"
B="$H/build"; APP="$B/HarborRender.app"
rm -rf "$APP" "$B/Assets.xcassets"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$B/Assets.xcassets"
echo '{"info":{"author":"xcode","version":1}}' > "$B/Assets.xcassets/Contents.json"
for d in "$APPSRC"/Assets.xcassets/City*.imageset; do cp -R "$d" "$B/Assets.xcassets/"; done
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.mistport.harbor-render</string>
<key>CFBundleExecutable</key><string>HarborRender</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
xcrun actool "$B/Assets.xcassets" --compile "$APP/Contents/Resources" --platform macosx --minimum-deployment-target 14.0 \
  --output-partial-info-plist "$B/partial.plist" >/dev/null
xcrun --sdk macosx swiftc -target arm64-apple-macos14.0 -parse-as-library -D DEBUG -O \
  "$H/Render.swift" "$APPSRC/CityLivingScene.swift" -o "$APP/Contents/MacOS/HarborRender"
echo built "$APP"
