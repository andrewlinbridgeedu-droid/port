#!/bin/bash
# 合成最终成片：视频 + 混音，响度统一到 -16 LUFS
set -e
F=$1; D=$(dirname "$0")/../build/$F; OUT=$(dirname "$0")/../output; mkdir -p "$OUT"
NAME=${2:-$F}
ffmpeg -y -loglevel error -i "$D/mix.wav" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=summary -ar 48000 "$D/mix_norm.wav" 2>&1 | tail -3
ffmpeg -y -loglevel error -i "$D/video.mp4" -i "$D/mix_norm.wav" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -movflags +faststart -shortest "$OUT/$NAME.mp4"
ls -la "$OUT/$NAME.mp4"
