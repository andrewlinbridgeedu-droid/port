#!/bin/bash
# 一次性准备：安装 Playwright 的 Chromium、下载开源字体（约 85 MB）。
# 可选：WITH_TTS=1 bash scripts/setup.sh 另外下载离线配音与识别模型（约 900 MB），仅在想改写解说词时需要。
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
command -v ffmpeg >/dev/null || { echo "需要 ffmpeg（macOS: brew install ffmpeg）"; exit 1; }
[ -d node_modules/playwright ] || npm install
npx playwright install chromium
mkdir -p fonts
get() { [ -s "fonts/$1" ] || { echo "下载 $1"; curl -fL --retry 3 -o "fonts/$1" "$2"; }; }
G=https://raw.githubusercontent.com/google/fonts/main/ofl
get NotoSerifSC.ttf "$G/notoserifsc/NotoSerifSC%5Bwght%5D.ttf"
get MaShanZheng.ttf "$G/mashanzheng/MaShanZheng-Regular.ttf"
get ZhiMangXing.ttf "$G/zhimangxing/ZhiMangXing-Regular.ttf"
get CormorantGaramond.ttf "$G/cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf"
get GFSDidot.ttf "$G/gfsdidot/GFSDidot-Regular.ttf"
get CormorantGaramondItalic.ttf "$G/cormorantgaramond/CormorantGaramond-Italic%5Bwght%5D.ttf"
get LXGWWenKai.ttf "https://github.com/lxgw/LxgwWenKai/releases/download/v1.520/LXGWWenKai-Regular.ttf"
get LXGWWenKaiMedium.ttf "https://github.com/lxgw/LxgwWenKai/releases/download/v1.520/LXGWWenKai-Medium.ttf"
if [ "$WITH_TTS" = "1" ]; then
  mkdir -p models && cd models
  R=https://github.com/k2-fsa/sherpa-onnx/releases/download
  [ -d kokoro-multi-lang-v1_1 ] || curl -fL "$R/tts-models/kokoro-multi-lang-v1_1.tar.bz2" | tar xj
  [ -d sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17 ] || curl -fL "$R/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2" | tar xj
  pip3 install sherpa-onnx soundfile scipy numpy
fi
echo "准备完成。试渲染一张静帧：node engine/render.js physics --still 60"
