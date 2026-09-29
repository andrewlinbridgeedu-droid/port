#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h:h}"
BUILD_DIR="${MISTPORT_CAMPAIGN_BUILD_DIR:-/tmp/mistport-campaign-app-build}"
APP_PARENT="${MISTPORT_CAMPAIGN_APP_PARENT:-$PROJECT_DIR/output/workshop-playtest-20260927}"
APP_DIR="$APP_PARENT/MistportWorkshopPlaytest.app"
# Refuse to replace external links or files. Only our own isolated app bundle is updated.
if [[ -L "$APP_PARENT" || -L "$APP_DIR" || ( -e "$APP_PARENT" && ! -d "$APP_PARENT" ) ]]; then
  print -u2 "Output path is not an ordinary directory: $APP_PARENT"; exit 1
fi
swift build --package-path "$SCRIPT_DIR" --scratch-path "$BUILD_DIR" -j 1
BIN_DIR="$(swift build --package-path "$SCRIPT_DIR" --scratch-path "$BUILD_DIR" --show-bin-path)"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/MistportCampaignSandbox" "$APP_DIR/Contents/MacOS/MistportCampaignSandbox"
# Configuration loader supports the signed macOS app resource location.
ditto "$BIN_DIR/MistportCombatCore_MistportCombatCore.bundle" "$APP_DIR/Contents/Resources/MistportCombatCore_MistportCombatCore.bundle"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.mistport.workshop-playtest</string>
<key>CFBundleName</key><string>雾港工坊试玩</string>
<key>CFBundleExecutable</key><string>MistportCampaignSandbox</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.3</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
if [[ "${MISTPORT_CAMPAIGN_OPEN_APP:-1}" == "1" ]]; then
  open "$APP_DIR"
fi
print "$APP_DIR"
