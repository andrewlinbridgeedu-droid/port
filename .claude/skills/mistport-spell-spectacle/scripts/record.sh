#!/usr/bin/env bash
# Record (or safety-check) formal spell rows with WholeSpellRound2Review20260922.
#
# usage: record.sh <output-dir> [--only=KEY1,KEY2] [--safety] [--off]
#   <output-dir>  relative to the repo root or absolute, e.g. output/spell-spectacle-20260927/probe1
#   --only        comma-separated row keys (prefix match, as the recorder does)
#   --safety      run cancellation/stop/retry checks instead of recording video
#   --off         record with the spectacle layer suppressed (diagnostic baseline)
#
# Prepares the hard-coded encoder path, copies the 98-row capture plan if the
# directory has none, refuses to run without the external SSD Library or while
# another Unity has the project open, retries once on the transient licence
# error, then prints the pass/fail summary and compares record/safety source
# SHA lists when both exist.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel)"
UNITY="/Applications/Unity/Hub/Editor/6000.3.20f1/Unity.app/Contents/MacOS/Unity"
PROJECT="$ROOT/UnityBattleSource"
ENC_ROOT="/tmp/mistport-vfx-encode"
ENC_BIN="$ENC_ROOT/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1"

[ $# -ge 1 ] || { sed -n '2,9p' "$0"; exit 2; }
OUT="$1"; shift
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac

ONLY=""; SAFETY=0; OFF=0
for arg in "$@"; do
  case "$arg" in
    --only=*) ONLY="${arg#--only=}" ;;
    --safety) SAFETY=1 ;;
    --off) OFF=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Encoder used by the recorder (lost when /tmp is cleared).
if [ ! -x "$ENC_BIN" ]; then
  echo "preparing encoder in $ENC_ROOT"
  mkdir -p "$ENC_ROOT"
  [ -x "$ENC_ROOT/venv/bin/python" ] || python3 -m venv "$ENC_ROOT/venv"
  "$ENC_ROOT/venv/bin/pip" install -q imageio-ffmpeg numpy pillow
  PKG="$("$ENC_ROOT/venv/bin/python" -c 'import imageio_ffmpeg,os;print(os.path.dirname(imageio_ffmpeg.__file__))')"
  ln -sfn "$PKG" "$ENC_ROOT/imageio_ffmpeg"
fi
[ -x "$ENC_BIN" ] || { echo "encoder still missing at $ENC_BIN" >&2; exit 1; }

# The project Library is a symlink to the external SSD; never recreate it.
if [ ! -d "$PROJECT/Library/" ]; then
  echo "UnityBattleSource/Library does not resolve (external SSD not mounted?). Mount it; do not recreate the link." >&2
  exit 1
fi
if pgrep -f "MacOS/Unity .*-projectPath $PROJECT" >/dev/null; then
  echo "another Unity process has this project open; wait for it to finish" >&2
  exit 1
fi

mkdir -p "$OUT"
[ -f "$OUT/capture-plan.json" ] || cp "$SKILL_DIR/assets/capture-plan-98.json" "$OUT/capture-plan.json"

MODE=$([ $SAFETY = 1 ] && echo safety || echo record)
TAG="$MODE-$([ -n "$ONLY" ] && echo "${ONLY//,/_}" || echo all)"
LOG="$OUT/$TAG.log"
ARGS=(-batchmode -projectPath "$PROJECT" -executeMethod WholeSpellRound2Review20260922.Begin "--round2-output=$OUT")
[ -n "$ONLY" ] && ARGS+=("--round2-only=$ONLY")
[ $SAFETY = 1 ] && ARGS+=(--round2-safety)
[ $OFF = 1 ] && ARGS+=(--spectacle-off)

run() { "$UNITY" "${ARGS[@]}" -logFile "$LOG" || true; }
echo "running $TAG -> $OUT"
run
if grep -q "No valid Unity Editor license" "$LOG" 2>/dev/null; then
  echo "transient licence error; retrying in 30s"
  sleep 30; run
fi

echo "---"
PASSED="$OUT/$TAG-passed.txt"; FAILED="$OUT/$TAG-failed.txt"
if [ -f "$FAILED" ]; then echo "FAILED checks:"; cat "$FAILED"; fi
if [ -f "$PASSED" ]; then echo "passed assertions: $(wc -l < "$PASSED" | tr -d ' ')"; else echo "no passed file; see $LOG"; fi
grep -E "error CS|ROUND2_FAIL" "$LOG" | head -5 || true
[ $SAFETY = 0 ] && [ -d "$OUT/after" ] && echo "videos in after/: $(ls "$OUT/after" | grep -c '\.mp4$')"

OTHER="$OUT/$([ $SAFETY = 1 ] && echo record || echo safety)-${TAG#*-}-source-sha256.txt"
MINE="$OUT/$TAG-source-sha256.txt"
if [ -f "$OTHER" ] && [ -f "$MINE" ]; then
  if diff -q <(cut -c1-64 "$MINE") <(cut -c1-64 "$OTHER") >/dev/null; then
    echo "record and safety ran on the same source ($(shasum -a 256 "$MINE" | cut -c1-12)…)"
  else
    echo "WARNING: record and safety source lists differ; rerun one of them" >&2
  fi
fi
