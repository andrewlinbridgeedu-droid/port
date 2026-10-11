#!/bin/bash
# 渲染四部片子并输出两种成片：
#   build/<片>/master.mp4   高码率母版（H.264 + AAC 192k）
#   output/<名>.mp4         便于传送的版本（1080p HEVC 两遍编码，控制在 29 MiB 内）
# 用法: bash scripts/deliver.sh [physics chemistry medicine literature]
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
declare -A NAME=([physics]=01_物理学奖_以冰为眼 [chemistry]=02_化学奖_积微成著 [medicine]=03_生理学或医学奖_以光为钥 [literature]=04_文学奖_与火为邻)
FILMS=${@:-physics chemistry medicine literature}
for F in $FILMS; do
  N=${NAME[$F]}; D=build/$F
  echo "== $F 渲染开始 $(date +%T)"
  node engine/render.js $F --workers ${WORKERS:-4}
  bash engine/finish.sh $F "$N" >/dev/null && mv "output/$N.mp4" "$D/master.mp4"
  DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$D/master.mp4")
  VB=$(python3 -c "print(int(((29*1024*1024*8) - 96000*$DUR) / $DUR * 0.97))")
  echo "== $F 压缩：时长 ${DUR}s，视频码率 ${VB} bps"
  ( cd $D && ffmpeg -v error -y -i master.mp4 -vf hqdn3d=1.2:1.2:3:3 -c:v libx265 -preset medium -b:v $VB -x265-params pass=1:log-level=error -an -f null /dev/null \
    && ffmpeg -v error -y -i master.mp4 -vf hqdn3d=1.2:1.2:3:3 -c:v libx265 -preset medium -b:v $VB -x265-params pass=2:log-level=error -tag:v hvc1 -c:a aac -b:a 96k -movflags +faststart "$ROOT/output/$N.mp4" \
    && rm -f x265_2pass.log* )
  echo "READY $ROOT/output/$N.mp4 $(du -h "output/$N.mp4" | cut -f1) $(date +%T)"
done
echo "ALL DONE"
