#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: scripts/import_gorest_sprite.sh <manifest.json> <source-sheet.png>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$1"
SOURCE_SHEET="$2"
NODE_BIN="/Users/andrewlin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"

if [ ! -f "$MANIFEST" ]; then
  echo "Missing manifest: $MANIFEST"
  exit 1
fi

if [ ! -f "$SOURCE_SHEET" ]; then
  echo "Missing source sheet: $SOURCE_SHEET"
  exit 1
fi

TARGET_IMAGE="$("$NODE_BIN" -e "const fs=require('fs'); const m=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); console.log(m.mistportImport.targetImage)" "$MANIFEST")"
TARGET_METADATA="$("$NODE_BIN" -e "const fs=require('fs'); const m=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); console.log(m.mistportImport.targetMetadata)" "$MANIFEST")"

mkdir -p "$ROOT_DIR/$(dirname "$TARGET_IMAGE")"
mkdir -p "$ROOT_DIR/$(dirname "$TARGET_METADATA")"

cp "$SOURCE_SHEET" "$ROOT_DIR/$TARGET_IMAGE"
cp "$MANIFEST" "$ROOT_DIR/$TARGET_METADATA"

echo "Imported:"
echo "  $TARGET_IMAGE"
echo "  $TARGET_METADATA"
