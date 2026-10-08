#!/bin/bash
# Fetch the offline Chinese TTS model, the ASR model used for pronunciation checks, and web fonts.
# usage: tools/setup.sh <cache-dir>     (then export TTS_DIR / ASR_DIR as printed)
set -e
D=${1:-$HOME/.cache/nobel-2026}
mkdir -p "$D/tts" "$D/asr" "$D/fonts"
pip install sherpa-onnx soundfile scipy pypinyin
cd "$D/tts"
[ -d matcha-icefall-zh-baker ] || { curl -sSL -o m.tar.bz2 https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/matcha-icefall-zh-baker.tar.bz2 && tar xjf m.tar.bz2 && rm m.tar.bz2; }
[ -f vocos-22khz-univ.onnx ] || curl -sSL -o vocos-22khz-univ.onnx https://github.com/k2-fsa/sherpa-onnx/releases/download/vocoder-models/vocos-22khz-univ.onnx
cd "$D/asr"
[ -d sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17 ] || { curl -sSL -o a.tar.bz2 https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2 && tar xjf a.tar.bz2 && rm a.tar.bz2; }
cd "$D/fonts"
[ -f package.json ] || npm init -y > /dev/null
npm i -q @fontsource/noto-serif-sc @fontsource/ma-shan-zheng lxgw-wenkai-webfont @fontsource/zcool-xiaowei @fontsource/cormorant-garamond @fontsource/noto-serif
cd - > /dev/null
ln -sfn "$D/fonts/node_modules" "$(dirname "$0")/../engine/fonts"
echo "export TTS_DIR=$D/tts ASR_DIR=$D/asr/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
