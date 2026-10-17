#!/bin/sh
# contrib.sh POINTS : cheat — set this save's city contribution points (simulator only); app must be stopped.
set -e
U=E64100C9-43DA-4B8C-996A-2D953A13219C
N=${1:-320}
xcrun simctl terminate $U com.yourcompany.mistport 2>/dev/null || true
sleep 1
D=$(xcrun simctl get_app_container $U com.yourcompany.mistport data)
P="$D/Library/Preferences/mistport.player-test-01-15.plist"
HEX=$(python3 -c "import json,sys;print(json.dumps({'ledger':{'points':int(sys.argv[1]),'receipts':[],'daily':{},'migratedPoints':0}},separators=(',',':')).encode().hex())" "$N")
xcrun simctl spawn $U defaults write "$P" mistport.city-contribution.v1 -data "$HEX"
echo "contribution set to $N"
