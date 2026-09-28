#!/bin/bash
# usage: record.sh <device-udid> <out.mp4> <seconds> <launch arguments...>
# Records the simulator screen while the harness runs with the given arguments.
DEV="$1"; OUT="$2"; SECS="$3"; shift 3
xcrun simctl terminate "$DEV" dev.mistport.harbor-harness >/dev/null 2>&1 || true
rm -f "$OUT"
xcrun simctl io "$DEV" recordVideo --codec h264 --force "$OUT" >/dev/null 2>&1 &
REC=$!
sleep 2
xcrun simctl launch "$DEV" dev.mistport.harbor-harness "$@" >/dev/null
sleep "$SECS"
kill -INT $REC
wait $REC 2>/dev/null
echo recorded "$OUT"
