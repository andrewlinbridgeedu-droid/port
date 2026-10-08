#!/bin/bash
# usage: tools/deliver.sh <id>  — 1080p HEVC copy under ~28 MiB for sharing
set -e
cd "$(dirname "$0")/.."
id=$1
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 out/$id.mp4)
vk=$(python3 -c "print(int(28.0*8*1048.576/$dur - 128))")
mkdir -p build/$id/pass
ffmpeg -v error -y -i out/$id.mp4 -an -c:v libx265 -preset medium -b:v ${vk}k -x265-params pass=1:stats=build/$id/pass/x265.log:log-level=error -f null /dev/null
ffmpeg -v error -y -i out/$id.mp4 -c:v libx265 -preset medium -b:v ${vk}k -x265-params pass=2:stats=build/$id/pass/x265.log:log-level=error -tag:v hvc1 \
  -c:a aac -b:a 128k -movflags +faststart "out/$id-share.mp4"
ls -la out/$id-share.mp4
