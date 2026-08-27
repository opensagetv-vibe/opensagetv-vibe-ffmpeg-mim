#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT/settings.ini"

FINAL_IMAGE="${SAGETV_BUILDER_IMAGE:-opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5}"
BUILDX_NAME="${SAGETV_BUILDX_NAME:-opensagetv-vibe-ffmpeg-mim-bootstrap}"

command -v docker >/dev/null 2>&1 || { echo "ERROR: Docker is required." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon is not reachable." >&2; exit 1; }

for image in \
  ghcr.io/btbn/ffmpeg-builds/linux64-gpl-9.0:latest \
  ghcr.io/btbn/ffmpeg-builds/win64-gpl-9.0:latest \
  ghcr.io/btbn/ffmpeg-builds/win32-gpl-9.0:latest \
  ghcr.io/btbn/ffmpeg-builds/base-win32:latest \
  ghcr.io/btbn/ffmpeg-builds/base:latest \
  sagetv-btbn-win32-gpl-9.0:local \
  sagetv-ffmpeg-mim-builder:ffmpeg9 \
  sagetv-ffmpeg-mim-builder:9.0.1-v1 \
  sagetv-ffmpeg-mim-builder:9.0.1-v2 \
  sagetv-ffmpeg-mim-builder:9.0.1-v3 \
  sagetv-ffmpeg-mim-builder:9.0.1-v4; do
  [[ "$image" == "$FINAL_IMAGE" ]] || docker image rm "$image" >/dev/null 2>&1 || true
done

docker buildx rm -f "$BUILDX_NAME" >/dev/null 2>&1 || true
printf 'Kept OpenSageTV Vibe builder image: %s\n' "$FINAL_IMAGE"
docker image inspect "$FINAL_IMAGE" --format 'ID={{.Id}} Size={{.Size}}'
