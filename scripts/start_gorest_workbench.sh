#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOREST_DIR="$ROOT_DIR/tools/gorest"
NODE_BIN="/Users/andrewlin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin"
PNPM_BIN="/Users/andrewlin/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/pnpm"

if [ ! -d "$GOREST_DIR" ]; then
  echo "Missing tools/gorest. Clone gorest before starting the workbench."
  exit 1
fi

cd "$GOREST_DIR"
export PATH="$NODE_BIN:$(dirname "$PNPM_BIN"):$PATH"
export PORT="${PORT:-3000}"

echo "Starting Mistport animation workbench at http://localhost:$PORT"
"$PNPM_BIN" run dev
