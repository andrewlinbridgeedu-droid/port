#!/bin/bash
# usage: [PAN=left|right] [CLOUD=0.9] [SEASON=summer] [RAIN=0.8] [WAIT=4] [CHROME=1] shoot.sh <device-udid> <outdir> <hour>...
# Relaunches the harness at each fixed hour and saves a screenshot per hour.
DEV="$1"; OUT="$2"; shift 2; mkdir -p "$OUT"
for h in "$@"; do
  xcrun simctl terminate "$DEV" dev.mistport.harbor-harness >/dev/null 2>&1 || true
  xcrun simctl launch "$DEV" dev.mistport.harbor-harness -MistportCityMute YES -MistportCityHour "$h" -MistportCityTimeScale 0 \
    ${RAIN:+-MistportCityRain $RAIN} ${SEASON:+-MistportCitySeason $SEASON} ${CLOUD:+-MistportCityNightCloud $CLOUD} ${PAN:+-HarnessPan $PAN} ${STORM:+-MistportCityStorm $STORM} ${GUST:+-MistportCityGust $GUST} ${SNOW:+-MistportCitySnowCover $SNOW} ${BOLT:+-MistportCityLightningAt $BOLT} ${TAGS:+-HarnessTags $TAGS} ${CHROME:+-HarnessChrome} >/dev/null
  sleep "${WAIT:-4}"
  xcrun simctl io "$DEV" screenshot "$OUT/h$h.png" >/dev/null 2>&1
done
echo shot "$OUT"
