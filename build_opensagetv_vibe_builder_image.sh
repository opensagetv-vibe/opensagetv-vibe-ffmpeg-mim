#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT/settings.ini"

IMAGE="${SAGETV_BUILDER_IMAGE:-opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5}"
BUILDX_NAME="${SAGETV_BUILDX_NAME:-opensagetv-vibe-ffmpeg-mim-bootstrap}"
FFMPEG_SRC="${FFMPEG_SOURCE_DIR:-$ROOT/work/docker-bootstrap/ffmpeg-${FFMPEG_TAG}}"
REBUILD=0
KEEP_CACHE="${KEEP_BOOTSTRAP_CACHE:-0}"

for arg in "$@"; do
  case "$arg" in
    --rebuild) REBUILD=1 ;;
    --keep-cache) KEEP_CACHE=1 ;;
    *) echo "ERROR: unknown option '$arg'" >&2; exit 2 ;;
  esac
done

command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker is required." >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERROR: Git is required." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon is not reachable." >&2; exit 1; }

if [[ "$REBUILD" == 0 ]] && docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "[builder-image] already available: $IMAGE"
  exit 0
fi

# Source cleanup is intentionally restricted to this repository's dedicated
# bootstrap cache even if FFMPEG_SOURCE_DIR is overridden.
case "$FFMPEG_SRC" in
  "$ROOT"/work/docker-bootstrap/*) ;;
  *) echo "ERROR: FFMPEG_SOURCE_DIR must be below $ROOT/work/docker-bootstrap" >&2; exit 2 ;;
esac

if [[ ! -d "$FFMPEG_SRC/.git" ]]; then
  rm -rf -- "$FFMPEG_SRC"
  mkdir -p "$(dirname "$FFMPEG_SRC")"
  git clone --filter=blob:none --depth 1 --branch "$FFMPEG_TAG" \
    https://github.com/FFmpeg/FFmpeg.git "$FFMPEG_SRC"
else
  git -C "$FFMPEG_SRC" fetch --depth 1 origin \
    "refs/tags/$FFMPEG_TAG:refs/tags/$FFMPEG_TAG" 2>/dev/null || true
  git -C "$FFMPEG_SRC" checkout -f "$FFMPEG_TAG" >/dev/null
  git -C "$FFMPEG_SRC" clean -fdx >/dev/null
fi

if docker buildx inspect "$BUILDX_NAME" >/dev/null 2>&1; then
  docker buildx rm -f "$BUILDX_NAME" >/dev/null
fi
docker buildx create --name "$BUILDX_NAME" --driver docker-container \
  --driver-opt network=host --use >/dev/null
docker buildx inspect --bootstrap "$BUILDX_NAME" >/dev/null

cleanup() {
  local rc=$?
  if [[ "$KEEP_CACHE" != 1 ]]; then
    docker buildx rm -f "$BUILDX_NAME" >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT

docker buildx build \
  --builder "$BUILDX_NAME" \
  --pull \
  --progress=plain \
  --load \
  -f "$ROOT/docker/Dockerfile" \
  -t "$IMAGE" \
  --build-arg "BTBN_BASE_IMAGE=${BTBN_BASE_IMAGE:-ghcr.io/btbn/ffmpeg-builds/base:latest}" \
  --build-arg "BTBN_LINUX_IMAGE=${BTBN_LINUX_IMAGE:-ghcr.io/btbn/ffmpeg-builds/linux64-gpl-9.0:latest}" \
  --build-arg "BTBN_WIN64_IMAGE=${BTBN_WINDOWS_X64_IMAGE:-ghcr.io/btbn/ffmpeg-builds/win64-gpl-9.0:latest}" \
  --build-arg "FFMPEG_TAG=$FFMPEG_TAG" \
  --build-arg "BUILDER_VERSION=9.0.1-v5" \
  --build-context "ffmpeg_src=$FFMPEG_SRC" \
  "$ROOT"

printf '[SUCCESS] OpenSageTV Vibe builder image: %s\n' "$IMAGE"
docker image inspect "$IMAGE" --format 'ID={{.Id}} Size={{.Size}}'
