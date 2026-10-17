#!/bin/sh
U=E64100C9-43DA-4B8C-996A-2D953A13219C
P=$1; N=${2:-12}
mkdir -p /private/tmp/playtest/burst
t0=$(python3 -c 'import time;print(int(time.time()*1000))')
i=0
while [ $i -lt $N ]; do
  t=$(python3 -c 'import time;print(int(time.time()*1000))')
  xcrun simctl io $U screenshot --type=jpeg "/private/tmp/playtest/burst/$P-$(printf %02d $i)-$((t-t0)).jpg" >/dev/null 2>&1
  i=$((i+1))
done
