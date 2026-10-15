#!/bin/sh
# stamina.sh [VALUE] : cheat — set this save's stamina (simulator only); app must be stopped.
set -e
U=E64100C9-43DA-4B8C-996A-2D953A13219C
N=${1:-100}
xcrun simctl terminate $U com.yourcompany.mistport 2>/dev/null || true
sleep 1
D=$(xcrun simctl get_app_container $U com.yourcompany.mistport data)
P="$D/Library/Preferences/mistport.player-test-01-15.plist"
HEX=$(python3 - "$P" "$N" <<'PY'
import plistlib, json, sys, time
d = plistlib.load(open(sys.argv[1], 'rb'))
v = json.loads(d['mistport.housing-stamina.v1'])
v['stamina']['value'] = float(sys.argv[2])
v['stamina']['settledAt'] = time.time()
print(json.dumps(v, separators=(',', ':')).encode().hex())
PY
)
xcrun simctl spawn $U defaults write "$P" mistport.housing-stamina.v1 -data "$HEX"
echo "stamina set to $N"
