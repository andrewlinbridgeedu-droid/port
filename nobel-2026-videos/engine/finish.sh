#!/bin/bash
# 合成成片：渲染出的画面 build/<片>/video.mp4 + 配乐混音
#   有 build/<片>/mix.wav（自己重新生成过音频）时用它并做响度标准化，
#   否则直接使用仓库里已标准化（−16 LUFS）的 assets/<片>/soundtrack.ogg。
# 用法: bash engine/finish.sh physics [输出文件名]
set -e
F=$1; ROOT="$(cd "$(dirname "$0")/.." && pwd)"; D="$ROOT/build/$F"; OUT="$ROOT/output"; mkdir -p "$OUT"
NAME=${2:-$F}
if [ -f "$D/mix.wav" ]; then
  ffmpeg -y -loglevel error -i "$D/mix.wav" -af loudnorm=I=-16:TP=-1.5:LRA=11 -ar 48000 "$D/mix_norm.wav"
  AUDIO="$D/mix_norm.wav"
else
  AUDIO="$ROOT/assets/$F/soundtrack.ogg"
fi
ffmpeg -y -loglevel error -i "$D/video.mp4" -i "$AUDIO" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -movflags +faststart -shortest "$OUT/$NAME.mp4"
ls -la "$OUT/$NAME.mp4"
