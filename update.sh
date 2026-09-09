#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; BUILD_ENV="${OPENSAGETV_VIBE_BUILD_ENV_ROOT:-$ROOT/../opensagetv-vibe-build-env}"
exec bash "$BUILD_ENV/scripts/component-update.sh" "$ROOT"
