#!/bin/sh
set -e
U=E64100C9-43DA-4B8C-996A-2D953A13219C
N=${1:-1}
xcrun simctl terminate $U com.yourcompany.mistport 2>/dev/null || true
sleep 1
D=$(xcrun simctl get_app_container $U com.yourcompany.mistport data)
P="$D/Library/Preferences/mistport.player-test-01-15.plist"
HEX=$(python3 - "$P" "$N" <<'PY'
import plistlib,sys,json
p,n=sys.argv[1],int(sys.argv[2])
d=plistlib.load(open(p,'rb'))
v=json.loads(d['mistport.daily-pacing.start.v1'])
v['start']-=86400*n
print(json.dumps(v,separators=(',',':')).encode().hex())
PY
)
xcrun simctl spawn $U defaults write "$P" mistport.daily-pacing.start.v1 -data "$HEX"
xcrun simctl launch $U com.yourcompany.mistport -MistportCityMute YES --developer-tools >/dev/null
echo launched
