#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${1:?Usage: $0 linux|windows|all|target [target-id]}"
shift || true

# shellcheck disable=SC1091
source "$ROOT/settings.ini"

IMAGE="${SAGETV_BUILDER_IMAGE:-sagetv-ffmpeg-mim-builder:9.0.1-v5}"
CONTAINER="${SAGETV_BUILDER_CONTAINER:-sagetv-ffmpeg-mim-builder}"

command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker is required." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon is not reachable." >&2; exit 1; }

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "ERROR: required builder image is missing: $IMAGE" >&2
  echo "Build it intentionally with: ./build_sagetv_builder_image.sh" >&2
  exit 1
fi

mkdir -p "$ROOT/output"

# There is intentionally ONE runtime container for every build mode.  The
# 'all' command builds Linux x64 and Windows x64 sequentially inside this one
# container.  Linux-only and Windows-only use the same container name.
if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  running="$(docker container inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || echo false)"
  if [[ "$running" == "true" ]]; then
    echo "ERROR: build container '$CONTAINER' is already running." >&2
    echo "Wait for the current build to finish, or stop it with:" >&2
    echo "  docker stop $CONTAINER" >&2
    exit 1
  fi
  # Remove a stale exited container left by an interrupted/older build.
  docker container rm -f "$CONTAINER" >/dev/null 2>&1 || true
fi

echo "[builder] image     : $IMAGE"
echo "[builder] container : $CONTAINER"
echo "[builder] mode      : $MODE"

exec docker run --rm -i \
  --name "$CONTAINER" \
  -e "HOST_UID=$(id -u)" \
  -e "HOST_GID=$(id -g)" \
  -v "$ROOT:/project" \
  -w /project \
  "$IMAGE" "$MODE" "$@"
