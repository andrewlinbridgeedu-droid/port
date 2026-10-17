#!/bin/sh
end=$(( $(date +%s) + $1 )); until [ $(date +%s) -ge $end ]; do sleep 1; done
/private/tmp/playtest/shot.sh $2
