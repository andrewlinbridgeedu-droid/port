#!/bin/bash
# usage: tools/make.sh <id> [parts]  — renders frames in parallel parts, mixes audio, muxes final mp4
set -e
cd "$(dirname "$0")/.."
id=$1; parts=${2:-2}
dur=$(python3 -c "import json;print(json.load(open('build/$id/timeline.json'))['duration'])")
seg=$(python3 -c "import math;print(math.ceil($dur/$parts))")
[ -f build/$id/mix.wav ] || python3 tools/audio.py $id
rm -f build/$id/parts.txt
pids=()
for ((i=0;i<parts;i++)); do
  from=$((i*seg)); to=$(((i+1)*seg))
  node render.mjs $id --video build/$id/part$i.mp4 --from $from --to $to > build/$id/render$i.log 2>&1 &
  pids+=($!)
  echo "file 'part$i.mp4'" >> build/$id/parts.txt
done
for p in "${pids[@]}"; do wait $p; done
mkdir -p out
ffmpeg -v error -y -f concat -safe 0 -i build/$id/parts.txt -i build/$id/mix.wav -map 0:v -map 1:a -c:v copy \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11" -ar 48000 -c:a aac -b:a 192k -shortest -movflags +faststart out/$id.mp4
ls -la out/$id.mp4
