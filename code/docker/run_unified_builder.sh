#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${1:?Usage: $0 linux|windows|all|target TARGET|info}"
shift || true
BUILD_ENV="${OPENSAGETV_VIBE_BUILD_ENV_DIR:-$ROOT/../opensagetv-vibe-build-env}"
DEV="$BUILD_ENV/opensagetv-vibe-dev.sh"

[[ -x "$DEV" ]] || {
  echo "ERROR: unified build wrapper not found: $DEV" >&2
  echo "Check out opensagetv-vibe-build-env beside this repository." >&2
  exit 1
}

case "$MODE" in
  linux) exec "$DEV" ffmpeg-linux "$@" ;;
  windows) exec "$DEV" ffmpeg-windows "$@" ;;
  info) exec "$DEV" ffmpeg-info "$@" ;;
  all)
    "$DEV" ffmpeg-linux "$@"
    exec "$DEV" ffmpeg-windows "$@"
    ;;
  target)
    case "${1:-}" in
      linux-x64) exec "$DEV" ffmpeg-linux ;;
      windows-x64) exec "$DEV" ffmpeg-windows ;;
      *) echo "ERROR: target must be linux-x64 or windows-x64" >&2; exit 2 ;;
    esac
    ;;
  *) echo "ERROR: unsupported mode: $MODE" >&2; exit 2 ;;
esac
