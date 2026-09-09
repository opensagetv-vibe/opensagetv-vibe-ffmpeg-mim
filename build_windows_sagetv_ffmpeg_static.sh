#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ "$(uname -s)" == Linux* ]] || { echo "ERROR: Run under Linux/WSL." >&2; exit 1; }
exec "$ROOT/code/docker/run_unified_builder.sh" windows
